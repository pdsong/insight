defmodule Insight.News do
  @moduledoc """
  新闻领域的 Context 模块。

  提供新闻、标签、爬取快照相关的业务逻辑接口，包括：
  - 新闻的创建、查询、更新
  - 爬取快照的创建和查询
  - 标签的 CRUD 和关联
  """
  import Ecto.Query
  alias Insight.Repo
  alias Insight.News.{NewsItem, CrawlSnapshot, CrawlSnapshotItem, Tag}

  # ============================================================
  # 新闻条目
  # ============================================================

  @doc "根据 up_id 查找新闻，不存在则返回 nil"
  def get_news_item_by_up_id(up_id) do
    Repo.get_by(NewsItem, up_id: up_id)
  end

  @doc "根据 ID 获取新闻"
  def get_news_item!(id), do: Repo.get!(NewsItem, id)

  @doc "创建新闻条目"
  def create_news_item(attrs) do
    %NewsItem{}
    |> NewsItem.changeset(attrs)
    |> Repo.insert()
  end

  @doc "创建或更新新闻（基于 up_id 去重）"
  def upsert_news_item(attrs) do
    case get_news_item_by_up_id(attrs[:up_id] || attrs["up_id"]) do
      nil -> create_news_item(attrs)
      existing -> update_news_item(existing, attrs)
    end
  end

  @doc "更新新闻条目"
  def update_news_item(%NewsItem{} = news_item, attrs) do
    news_item
    |> NewsItem.changeset(attrs)
    |> Repo.update()
  end

  @doc "获取新闻条目的 changeset（用于表单）"
  def change_news_item(%NewsItem{} = news_item, attrs \\ %{}) do
    NewsItem.changeset(news_item, attrs)
  end

  # ============================================================
  # 爬取快照
  # ============================================================

  @doc "创建一个新的爬取快照"
  def create_crawl_snapshot(attrs) do
    %CrawlSnapshot{}
    |> CrawlSnapshot.changeset(attrs)
    |> Repo.insert()
  end

  @doc "获取指定类型的最近一次爬取快照"
  def get_latest_snapshot(source_type) do
    CrawlSnapshot
    |> where([s], s.source_type == ^source_type)
    |> order_by([s], desc: s.crawled_at)
    |> limit(1)
    |> Repo.one()
  end

  @doc "获取最近一次快照中的新闻列表（按排名排序）"
  def list_latest_news(source_type) do
    case get_latest_snapshot(source_type) do
      nil ->
        []

      snapshot ->
        CrawlSnapshotItem
        |> where([csi], csi.crawl_snapshot_id == ^snapshot.id)
        |> join(:inner, [csi], n in NewsItem, on: csi.news_item_id == n.id)
        |> order_by([csi], asc: csi.rank)
        |> select([csi, n], %{
          news_item: n,
          rank: csi.rank,
          score: csi.score_at_crawl,
          comments_count: csi.comments_count_at_crawl
        })
        |> Repo.all()
    end
  end

  @doc "为快照添加新闻关联条目"
  def create_crawl_snapshot_item(attrs) do
    %CrawlSnapshotItem{}
    |> CrawlSnapshotItem.changeset(attrs)
    |> Repo.insert()
  end

  # ============================================================
  # 标签
  # ============================================================

  @doc "获取所有系统标签"
  def list_system_tags do
    Tag
    |> where([t], t.type == "system")
    |> order_by([t], asc: t.name)
    |> Repo.all()
  end

  @doc "获取用户的自定义标签"
  def list_user_tags(user_id) do
    Tag
    |> where([t], t.type == "user" and t.user_id == ^user_id)
    |> order_by([t], asc: t.name)
    |> Repo.all()
  end

  @doc "获取所有标签（系统 + 用户自定义）"
  def list_all_tags(user_id) do
    Tag
    |> where([t], t.type == "system" or (t.type == "user" and t.user_id == ^user_id))
    |> order_by([t], asc: t.name)
    |> Repo.all()
  end

  @doc "根据 ID 获取标签"
  def get_tag!(id), do: Repo.get!(Tag, id)

  @doc "创建标签"
  def create_tag(attrs) do
    %Tag{}
    |> Tag.changeset(attrs)
    |> Repo.insert()
  end

  @doc "更新标签"
  def update_tag(%Tag{} = tag, attrs) do
    tag
    |> Tag.changeset(attrs)
    |> Repo.update()
  end

  @doc "删除标签"
  def delete_tag(%Tag{} = tag), do: Repo.delete(tag)

  @doc "获取标签的 changeset"
  def change_tag(%Tag{} = tag, attrs \\ %{}) do
    Tag.changeset(tag, attrs)
  end

  @doc "为新闻关联标签"
  def add_tag_to_news(%NewsItem{} = news_item, %Tag{} = tag) do
    Repo.insert_all(
      "news_tags",
      [
        %{news_item_id: news_item.id, tag_id: tag.id}
      ],
      on_conflict: :nothing
    )
  end
end
