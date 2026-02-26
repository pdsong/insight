defmodule Insight.BlockingFilterTest do
  @moduledoc """
  屏蔽过滤测试：关键词、域名、标签屏蔽。
  """
  use Insight.DataCase

  alias Insight.News
  alias Insight.Interactions
  import Insight.AccountsFixtures
  import Insight.NewsFixtures

  setup do
    user = user_fixture()
    %{user: user}
  end

  describe "关键词屏蔽" do
    test "屏蔽后匹配标题的新闻不再返回", %{user: user} do
      _news1 = news_item_fixture(%{title: "Bitcoin price surges"})
      _news2 = news_item_fixture(%{title: "Elixir is awesome"})

      Interactions.create_blocked_item(%{
        user_id: user.id,
        block_type: "keyword",
        value: "Bitcoin"
      })

      result = News.list_news_paginated(user_id: user.id)
      titles = Enum.map(result.items, & &1.title)
      refute "Bitcoin price surges" in titles
      assert "Elixir is awesome" in titles
    end

    test "屏蔽中文标题关键词", %{user: user} do
      _news1 = news_item_fixture(%{title: "Crypto news", title_zh: "加密货币新闻"})
      _news2 = news_item_fixture(%{title: "Tech update", title_zh: "技术更新"})

      Interactions.create_blocked_item(%{user_id: user.id, block_type: "keyword", value: "加密货币"})

      result = News.list_news_paginated(user_id: user.id)
      titles_zh = Enum.map(result.items, & &1.title_zh)
      refute "加密货币新闻" in titles_zh
      assert "技术更新" in titles_zh
    end
  end

  describe "域名屏蔽" do
    test "屏蔽后该域名的新闻不再返回", %{user: user} do
      _news1 = news_item_fixture(%{title: "Spam article", domain: "spam.com"})
      _news2 = news_item_fixture(%{title: "Good article", domain: "good.com"})

      Interactions.create_blocked_item(%{
        user_id: user.id,
        block_type: "domain",
        value: "spam.com"
      })

      result = News.list_news_paginated(user_id: user.id)
      domains = Enum.map(result.items, & &1.domain)
      refute "spam.com" in domains
      assert "good.com" in domains
    end
  end

  describe "标签屏蔽" do
    test "屏蔽后带该标签的新闻不再返回", %{user: user} do
      news1 = news_item_fixture(%{title: "Crypto news"})
      _news2 = news_item_fixture(%{title: "Elixir news"})

      tag = system_tag_fixture(%{name: "block_test_crypto_#{System.unique_integer([:positive])}"})
      News.add_tag_to_news(news1, tag)

      Interactions.create_blocked_item(%{user_id: user.id, block_type: "tag", value: tag.name})

      result = News.list_news_paginated(user_id: user.id)
      titles = Enum.map(result.items, & &1.title)
      refute "Crypto news" in titles
      assert "Elixir news" in titles
    end
  end

  describe "无屏蔽规则" do
    test "不传 user_id 时不过滤", %{user: _user} do
      _news1 = news_item_fixture(%{title: "Should appear"})
      result = News.list_news_paginated()
      titles = Enum.map(result.items, & &1.title)
      assert "Should appear" in titles
    end

    test "用户没有屏蔽规则时全部返回", %{user: user} do
      _news1 = news_item_fixture(%{title: "All visible"})
      result = News.list_news_paginated(user_id: user.id)
      titles = Enum.map(result.items, & &1.title)
      assert "All visible" in titles
    end
  end

  describe "blocked_items CRUD" do
    test "创建和列出屏蔽规则", %{user: user} do
      {:ok, _} =
        Interactions.create_blocked_item(%{user_id: user.id, block_type: "keyword", value: "test"})

      {:ok, _} =
        Interactions.create_blocked_item(%{
          user_id: user.id,
          block_type: "domain",
          value: "bad.com"
        })

      items = Interactions.list_blocked_items(user.id)
      assert length(items) == 2
    end

    test "删除屏蔽规则", %{user: user} do
      {:ok, item} =
        Interactions.create_blocked_item(%{user_id: user.id, block_type: "keyword", value: "test"})

      {:ok, _} = Interactions.delete_blocked_item(item)
      assert Interactions.list_blocked_items(user.id) == []
    end

    test "重复创建同类型同值会失败（唯一约束）", %{user: user} do
      {:ok, _} =
        Interactions.create_blocked_item(%{user_id: user.id, block_type: "keyword", value: "dup"})

      {:error, _} =
        Interactions.create_blocked_item(%{user_id: user.id, block_type: "keyword", value: "dup"})
    end
  end
end
