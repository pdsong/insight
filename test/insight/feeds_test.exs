defmodule Insight.FeedsTest do
  @moduledoc """
  自定义阅读流测试：CRUD + 查询引擎。
  """
  use Insight.DataCase

  alias Insight.Feeds
  import Insight.AccountsFixtures
  import Insight.NewsFixtures

  setup do
    user = user_fixture()
    %{user: user}
  end

  describe "CRUD" do
    test "创建自定义阅读流", %{user: user} do
      {:ok, feed} =
        Feeds.create_custom_feed(%{
          user_id: user.id,
          name: "AI 前沿",
          rules: %{"tags" => ["AI"], "keywords" => ["GPT"]}
        })

      assert feed.name == "AI 前沿"
      assert feed.rules["tags"] == ["AI"]
    end

    test "列出用户的所有阅读流", %{user: user} do
      {:ok, _} = Feeds.create_custom_feed(%{user_id: user.id, name: "Feed A", rules: %{}})
      {:ok, _} = Feeds.create_custom_feed(%{user_id: user.id, name: "Feed B", rules: %{}})

      feeds = Feeds.list_custom_feeds(user.id)
      assert length(feeds) == 2
    end

    test "更新阅读流", %{user: user} do
      {:ok, feed} = Feeds.create_custom_feed(%{user_id: user.id, name: "Old", rules: %{}})
      {:ok, updated} = Feeds.update_custom_feed(feed, %{name: "New"})
      assert updated.name == "New"
    end

    test "删除阅读流", %{user: user} do
      {:ok, feed} = Feeds.create_custom_feed(%{user_id: user.id, name: "Delete me", rules: %{}})
      {:ok, _} = Feeds.delete_custom_feed(feed)
      assert Feeds.list_custom_feeds(user.id) == []
    end
  end

  describe "query_feed/2 查询引擎" do
    test "按标签筛选", %{user: user} do
      news1 = news_item_fixture(%{title: "AI breakthrough"})
      _news2 = news_item_fixture(%{title: "Cooking tips"})

      tag = system_tag_fixture(%{name: "feed_test_ai_#{System.unique_integer([:positive])}"})
      Insight.News.add_tag_to_news(news1, tag)

      {:ok, feed} =
        Feeds.create_custom_feed(%{
          user_id: user.id,
          name: "AI Feed",
          rules: %{"tags" => [tag.name]}
        })

      result = Feeds.query_feed(feed)
      titles = Enum.map(result.items, & &1.title)
      assert "AI breakthrough" in titles
      refute "Cooking tips" in titles
    end

    test "按关键词筛选", %{user: user} do
      _news1 = news_item_fixture(%{title: "Elixir Phoenix tutorial"})
      _news2 = news_item_fixture(%{title: "Java Spring boot"})

      {:ok, feed} =
        Feeds.create_custom_feed(%{
          user_id: user.id,
          name: "Elixir Feed",
          rules: %{"keywords" => ["Elixir"]}
        })

      result = Feeds.query_feed(feed)
      titles = Enum.map(result.items, & &1.title)
      assert "Elixir Phoenix tutorial" in titles
      refute "Java Spring boot" in titles
    end

    test "标签 + 关键词组合（AND 逻辑）", %{user: user} do
      news1 = news_item_fixture(%{title: "AI Keyword match tagged"})
      _news2 = news_item_fixture(%{title: "Keyword match untagged"})
      news3 = news_item_fixture(%{title: "Tagged only no keyword"})
      _news4 = news_item_fixture(%{title: "Unrelated stuff"})

      tag = system_tag_fixture(%{name: "feed_combo_#{System.unique_integer([:positive])}"})
      Insight.News.add_tag_to_news(news1, tag)
      Insight.News.add_tag_to_news(news3, tag)

      {:ok, feed} =
        Feeds.create_custom_feed(%{
          user_id: user.id,
          name: "Combo",
          rules: %{"tags" => [tag.name], "keywords" => ["Keyword match"]}
        })

      result = Feeds.query_feed(feed)
      titles = Enum.map(result.items, & &1.title)
      # 只有同时满足标签 AND 关键词的新闻才会返回
      assert "AI Keyword match tagged" in titles
      refute "Keyword match untagged" in titles
      refute "Tagged only no keyword" in titles
      refute "Unrelated stuff" in titles
    end

    test "空规则返回所有新闻", %{user: user} do
      _news = news_item_fixture(%{title: "Should appear"})

      {:ok, feed} =
        Feeds.create_custom_feed(%{user_id: user.id, name: "Empty", rules: %{}})

      result = Feeds.query_feed(feed)
      assert result.total >= 1
    end

    test "分页正常工作", %{user: user} do
      for i <- 1..5, do: news_item_fixture(%{title: "Feed page test #{i}"})

      {:ok, feed} = Feeds.create_custom_feed(%{user_id: user.id, name: "Paged", rules: %{}})
      result = Feeds.query_feed(feed, page: 1, per_page: 2)
      assert length(result.items) == 2
      assert result.total >= 5
    end
  end
end
