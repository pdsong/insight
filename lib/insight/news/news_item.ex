defmodule Insight.News.NewsItem do
  @moduledoc """
  新闻条目 Schema。

  对应 HackerNews 上的一条新闻。`up_id` 是 HN 上的原始 ID，
  用于去重。`title_zh`、`summary_zh`、`keywords` 由 AI 异步填充。
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "news_items" do
    # HN 原始字段
    field :up_id, :integer
    field :title, :string
    field :url, :string
    field :domain, :string
    field :hn_user, :string
    field :posted_at, :utc_datetime

    # AI 填充字段
    field :title_zh, :string
    field :summary_zh, :string
    field :keywords, :string

    # 关联
    many_to_many :tags, Insight.News.Tag, join_through: "news_tags"
    has_many :crawl_snapshot_items, Insight.News.CrawlSnapshotItem

    timestamps(type: :utc_datetime)
  end

  @doc "创建/更新新闻条目的 changeset"
  def changeset(news_item, attrs) do
    news_item
    |> cast(attrs, [
      :up_id,
      :title,
      :url,
      :domain,
      :hn_user,
      :posted_at,
      :title_zh,
      :summary_zh,
      :keywords
    ])
    |> validate_required([:up_id, :title])
    |> unique_constraint(:up_id)
  end
end
