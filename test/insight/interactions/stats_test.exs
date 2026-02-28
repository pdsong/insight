defmodule Insight.Interactions.StatsTest do
  use Insight.DataCase

  alias Insight.Interactions
  alias Insight.Interactions.Stats
  import Insight.AccountsFixtures
  import Insight.NewsFixtures

  setup do
    user = user_fixture()
    {:ok, tag1} = Insight.News.create_tag(%{name: "TagA", type: "system"})
    {:ok, tag2} = Insight.News.create_tag(%{name: "TagB", type: "system"})

    news1 = news_item_fixture(%{title: "Test 1"})
    Insight.News.add_tag_to_news(news1, tag1)

    news2 = news_item_fixture(%{title: "Test 2"})
    Insight.News.add_tag_to_news(news2, tag2)

    news3 = news_item_fixture(%{title: "Test 3"})
    Insight.News.add_tag_to_news(news3, tag1)
    Insight.News.add_tag_to_news(news3, tag2)

    %{user: user, news1: news1, news2: news2, news3: news3, tag1: tag1, tag2: tag2}
  end

  describe "get_tag_distribution/1" do
    test "计算标签命中次数及排序", %{
      user: user,
      news1: news1,
      news2: news2,
      news3: news3,
      tag1: tag1,
      tag2: tag2
    } do
      # User interacts with news1 (TagA) => count 1 for TagA
      Interactions.toggle_interaction(user.id, news1.id, "read")

      # User interacts with news3 (TagA, TagB) => count 2 for TagA, count 1 for TagB
      Interactions.toggle_interaction(user.id, news3.id, "bookmark")

      # User interacts with news2 (TagB) => count 2 for TagA, count 2 for TagB
      Interactions.toggle_interaction(user.id, news2.id, "like")

      dist = Stats.get_tag_distribution(user.id)

      assert length(dist) == 2
      # 由于两者都是 2 分，排序可能不固定，但积分应该是被正确合计的
      assert Enum.find(dist, &(&1.name == tag1.name)).score == 2
      assert Enum.find(dist, &(&1.name == tag2.name)).score == 2
    end
  end

  describe "get_user_achievements/1" do
    test "新用户返回默认称号", %{user: user} do
      achievements = Stats.get_user_achievements(user.id)
      assert achievements.reads == 0
      assert achievements.likes == 0
      assert achievements.bookmarks == 0
      assert Enum.member?(achievements.titles, "潜水新手")
    end

    test "达到阈值返回对应称号", %{user: user} do
      # Simulate reading 6 different articles
      for i <- 1..6 do
        news = news_item_fixture(%{title: "Read Article #{i}", up_id: 1000 + i})

        Interactions.create_interaction(%{user_id: user.id, news_item_id: news.id, action: "read"})
      end

      # Simulate liking 11 different articles
      for j <- 1..11 do
        news = news_item_fixture(%{title: "Like Article #{j}", up_id: 2000 + j})

        Interactions.create_interaction(%{user_id: user.id, news_item_id: news.id, action: "like"})
      end

      achievements = Stats.get_user_achievements(user.id)
      assert achievements.reads >= 6
      assert achievements.likes >= 11

      titles = achievements.titles
      assert Enum.member?(titles, "初级探索者")
      assert Enum.member?(titles, "点赞狂魔")
      refute Enum.member?(titles, "潜水新手")
    end
  end

  describe "get_memory_arc/1" do
    test "返回用户喜欢或收藏过的内容", %{user: user, news2: news2} do
      # 无交互，应为 nil
      assert is_nil(Stats.get_memory_arc(user.id))

      Interactions.toggle_interaction(user.id, news2.id, "like")

      # 再次获取，应该会拿到 news2
      item = Stats.get_memory_arc(user.id)
      refute is_nil(item)
      assert item.id == news2.id
    end
  end
end
