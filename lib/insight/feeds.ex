defmodule Insight.Feeds do
  @moduledoc """
  自定义阅读流领域的 Context 模块。

  提供自定义 Feed 的 CRUD 接口。
  """
  import Ecto.Query
  alias Insight.Repo
  alias Insight.Feeds.CustomFeed

  @doc "获取用户的所有自定义阅读流"
  def list_custom_feeds(user_id) do
    CustomFeed
    |> where([f], f.user_id == ^user_id)
    |> order_by([f], asc: f.name)
    |> Repo.all()
  end

  @doc "根据 ID 获取自定义阅读流"
  def get_custom_feed!(id), do: Repo.get!(CustomFeed, id)

  @doc "创建自定义阅读流"
  def create_custom_feed(attrs) do
    %CustomFeed{}
    |> CustomFeed.changeset(attrs)
    |> Repo.insert()
  end

  @doc "更新自定义阅读流"
  def update_custom_feed(%CustomFeed{} = feed, attrs) do
    feed
    |> CustomFeed.changeset(attrs)
    |> Repo.update()
  end

  @doc "删除自定义阅读流"
  def delete_custom_feed(%CustomFeed{} = feed), do: Repo.delete(feed)

  @doc "获取自定义阅读流的 changeset"
  def change_custom_feed(%CustomFeed{} = feed, attrs \\ %{}) do
    CustomFeed.changeset(feed, attrs)
  end
end
