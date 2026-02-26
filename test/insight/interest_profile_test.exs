defmodule Insight.InterestProfileTest do
  @moduledoc """
  兴趣画像算法及行为测试。
  """
  use Insight.DataCase

  alias Insight.Interactions
  import Insight.AccountsFixtures
  import Insight.NewsFixtures

  setup do
    user = user_fixture()
    tag1 = Insight.News.create_tag(%{name: "TagA", type: "system"}) |> elem(1)
    tag2 = Insight.News.create_tag(%{name: "TagB", type: "system"}) |> elem(1)

    news1 = news_item_fixture(%{title: "Test 1"})
    Insight.News.add_tag_to_news(news1, tag1)

    news2 = news_item_fixture(%{title: "Test 2"})
    Insight.News.add_tag_to_news(news2, tag2)

    news3 = news_item_fixture(%{title: "Test 3"})
    Insight.News.add_tag_to_news(news3, tag1)
    Insight.News.add_tag_to_news(news3, tag2)

    %{user: user, tag1: tag1, tag2: tag2, news1: news1, news2: news2, news3: news3}
  end

  describe "calculate_all_user_interest_profiles/1" do
    test "正确计算交互权重", %{
      user: user,
      tag1: tag1,
      news1: news1,
      news2: news2,
      news3: news3
    } do
      # like: +2, read: +1，总共 news1 tag1 应该有 3 分
      Interactions.toggle_like_dislike(user.id, news1.id, "like")
      Interactions.create_interaction(%{user_id: user.id, news_item_id: news1.id, action: "read"})

      # bookmark: +1.5，总共 news2 tag2 应该有 1.5 分
      Interactions.toggle_interaction(user.id, news2.id, "bookmark")

      # dislike: -2，总共 news3 tag1, tag2 各扣 2 分
      Interactions.toggle_like_dislike(user.id, news3.id, "dislike")

      assert :ok == Interactions.calculate_all_user_interest_profiles(user.id)

      profiles = Interactions.list_user_interest_profiles(user.id)
      # tag1 = 3 - 2 = 1.0
      # tag2 = 1.5 - 2 = -0.5 (不保留低于 0.1 的)

      assert length(profiles) == 1
      p1 = hd(profiles)

      assert p1.tag_id == tag1.id
      assert p1.weight == 1.0
    end

    test "多次交互后保留正向画像按权重排序", %{user: user, tag1: tag1, tag2: tag2, news1: news1, news2: news2} do
      # tag1: +2
      Interactions.toggle_like_dislike(user.id, news1.id, "like")
      # tag2: +1
      Interactions.create_interaction(%{user_id: user.id, news_item_id: news2.id, action: "read"})

      assert :ok == Interactions.calculate_all_user_interest_profiles(user.id)

      profiles = Interactions.list_user_interest_profiles(user.id)
      assert length(profiles) == 2
      [p1, p2] = profiles

      # 获取的是按降序的
      assert p1.tag_id == tag1.id
      assert p1.weight == 2.0

      assert p2.tag_id == tag2.id
      assert p2.weight == 1.0
    end
  end
end
