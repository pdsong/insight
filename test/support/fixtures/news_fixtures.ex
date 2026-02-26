defmodule Insight.NewsFixtures do
  @moduledoc """
  新闻相关测试 fixtures。
  """

  alias Insight.News

  @doc "创建新闻条目 fixture"
  def news_item_fixture(attrs \\ %{}) do
    {:ok, news_item} =
      attrs
      |> Enum.into(%{
        up_id: System.unique_integer([:positive]),
        title: "Test News #{System.unique_integer([:positive])}",
        url: "https://example.com/#{System.unique_integer([:positive])}",
        domain: "example.com",
        hn_user: "testuser"
      })
      |> News.create_news_item()

    news_item
  end

  @doc "创建系统标签 fixture"
  def system_tag_fixture(attrs \\ %{}) do
    {:ok, tag} =
      attrs
      |> Enum.into(%{
        name: "tag_#{System.unique_integer([:positive])}",
        type: "system"
      })
      |> News.create_tag()

    tag
  end

  @doc "创建用户标签 fixture"
  def user_tag_fixture(user_id, attrs \\ %{}) do
    {:ok, tag} =
      attrs
      |> Enum.into(%{
        name: "user_tag_#{System.unique_integer([:positive])}",
        type: "user",
        user_id: user_id
      })
      |> News.create_tag()

    tag
  end
end
