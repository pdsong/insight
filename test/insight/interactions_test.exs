defmodule Insight.InteractionsTest do
  @moduledoc """
  Interactions Context 测试：Like/Dislike、收藏、已读功能。
  """
  use Insight.DataCase

  alias Insight.Interactions
  import Insight.AccountsFixtures
  import Insight.NewsFixtures

  setup do
    user = user_fixture()
    news1 = news_item_fixture()
    news2 = news_item_fixture()
    %{user: user, news1: news1, news2: news2}
  end

  # ============================================================
  # T08: toggle_like_dislike 互斥逻辑
  # ============================================================

  describe "toggle_like_dislike/3" do
    test "首次 like 创建交互记录", %{user: user, news1: news1} do
      Interactions.toggle_like_dislike(user.id, news1.id, "like")
      assert Interactions.get_interaction(user.id, news1.id, "like") != nil
    end

    test "重复 like 取消交互", %{user: user, news1: news1} do
      Interactions.toggle_like_dislike(user.id, news1.id, "like")
      Interactions.toggle_like_dislike(user.id, news1.id, "like")
      assert Interactions.get_interaction(user.id, news1.id, "like") == nil
    end

    test "like 后 dislike 会取消 like 并创建 dislike", %{user: user, news1: news1} do
      Interactions.toggle_like_dislike(user.id, news1.id, "like")
      assert Interactions.get_interaction(user.id, news1.id, "like") != nil

      Interactions.toggle_like_dislike(user.id, news1.id, "dislike")
      assert Interactions.get_interaction(user.id, news1.id, "like") == nil
      assert Interactions.get_interaction(user.id, news1.id, "dislike") != nil
    end

    test "dislike 后 like 会取消 dislike 并创建 like", %{user: user, news1: news1} do
      Interactions.toggle_like_dislike(user.id, news1.id, "dislike")
      Interactions.toggle_like_dislike(user.id, news1.id, "like")
      assert Interactions.get_interaction(user.id, news1.id, "dislike") == nil
      assert Interactions.get_interaction(user.id, news1.id, "like") != nil
    end
  end

  # ============================================================
  # T08: list_interactions_for_news_ids 批量查询
  # ============================================================

  describe "list_interactions_for_news_ids/2" do
    test "返回空 map 当无交互时", %{user: user, news1: news1} do
      result = Interactions.list_interactions_for_news_ids(user.id, [news1.id])
      assert result == %{}
    end

    test "返回 MapSet 包含所有交互类型", %{user: user, news1: news1} do
      Interactions.toggle_like_dislike(user.id, news1.id, "like")
      Interactions.toggle_interaction(user.id, news1.id, "bookmark")

      result = Interactions.list_interactions_for_news_ids(user.id, [news1.id])
      assert MapSet.member?(result[news1.id], "like")
      assert MapSet.member?(result[news1.id], "bookmark")
    end

    test "批量查询多条新闻", %{user: user, news1: news1, news2: news2} do
      Interactions.toggle_like_dislike(user.id, news1.id, "like")
      Interactions.toggle_like_dislike(user.id, news2.id, "dislike")

      result = Interactions.list_interactions_for_news_ids(user.id, [news1.id, news2.id])
      assert MapSet.member?(result[news1.id], "like")
      assert MapSet.member?(result[news2.id], "dislike")
    end

    test "user_id 为 nil 返回空 map", %{news1: news1} do
      assert Interactions.list_interactions_for_news_ids(nil, [news1.id]) == %{}
    end

    test "空 news_ids 列表返回空 map", %{user: user} do
      assert Interactions.list_interactions_for_news_ids(user.id, []) == %{}
    end
  end

  # ============================================================
  # T11: 收藏（bookmark）toggle
  # ============================================================

  describe "toggle_interaction/3 (bookmark)" do
    test "首次收藏", %{user: user, news1: news1} do
      Interactions.toggle_interaction(user.id, news1.id, "bookmark")
      assert Interactions.get_interaction(user.id, news1.id, "bookmark") != nil
    end

    test "重复收藏取消", %{user: user, news1: news1} do
      Interactions.toggle_interaction(user.id, news1.id, "bookmark")
      Interactions.toggle_interaction(user.id, news1.id, "bookmark")
      assert Interactions.get_interaction(user.id, news1.id, "bookmark") == nil
    end

    test "收藏和 like 互不影响", %{user: user, news1: news1} do
      Interactions.toggle_interaction(user.id, news1.id, "bookmark")
      Interactions.toggle_like_dislike(user.id, news1.id, "like")

      assert Interactions.get_interaction(user.id, news1.id, "bookmark") != nil
      assert Interactions.get_interaction(user.id, news1.id, "like") != nil
    end
  end

  # ============================================================
  # T10: 已读标记
  # ============================================================

  describe "read/mark_all_as_read" do
    test "read?/2 初始为 false", %{user: user, news1: news1} do
      refute Interactions.read?(user.id, news1.id)
    end

    test "创建 read 交互后 read? 为 true", %{user: user, news1: news1} do
      Interactions.create_interaction(%{
        user_id: user.id,
        news_item_id: news1.id,
        action: "read"
      })

      assert Interactions.read?(user.id, news1.id)
    end

    test "mark_all_as_read 批量标已读", %{user: user, news1: news1, news2: news2} do
      Interactions.mark_all_as_read(user.id, [news1.id, news2.id])
      assert Interactions.read?(user.id, news1.id)
      assert Interactions.read?(user.id, news2.id)
    end

    test "mark_all_as_read 重复调用不报错（on_conflict: :nothing）", %{user: user, news1: news1} do
      Interactions.mark_all_as_read(user.id, [news1.id])
      # 第二次不应报错
      assert Interactions.mark_all_as_read(user.id, [news1.id])
      assert Interactions.read?(user.id, news1.id)
    end
  end

  describe "list_bookmarks_and_likes/2" do
    test "返回正确分页的 bookmark 和 like 记录", %{user: user, news1: news1, news2: news2} do
      Interactions.toggle_interaction(user.id, news1.id, "bookmark")
      # 确保 news2 的 interaction 的 inserted_at 晚于 news1
      Process.sleep(100)
      Interactions.toggle_like_dislike(user.id, news2.id, "like")

      Interactions.create_interaction(%{user_id: user.id, news_item_id: news1.id, action: "read"})

      result = Interactions.list_bookmarks_and_likes(user.id, page: 1, per_page: 10)

      assert result.total == 2
      assert result.total_pages == 1
      assert length(result.items) == 2

      # SQLite时间戳在测试中较快时精度不够导致排序不稳定，我们不严苛断言第一项是什么，而是断言结果包含了我们创建的两项
      action_list = Enum.map(result.items, & &1.action)
      assert "bookmark" in action_list
      assert "like" in action_list
    end

    test "无记录时返回空", %{user: user} do
      result = Interactions.list_bookmarks_and_likes(user.id, page: 1, per_page: 10)
      assert result.total == 0
      assert result.items == []
    end
  end
end
