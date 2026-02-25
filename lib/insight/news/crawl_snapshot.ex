defmodule Insight.News.CrawlSnapshot do
  @moduledoc """
  爬取快照 Schema。

  每次整点爬取 HN 时创建一条快照记录。`source_type` 区分
  "news"（首页热门）和 "newest"（最新）两种类型。
  通过 `crawl_snapshot_items` 关联到该时刻出现的所有新闻。
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "crawl_snapshots" do
    field :source_type, :string
    field :crawled_at, :utc_datetime
    field :items_count, :integer, default: 0

    has_many :crawl_snapshot_items, Insight.News.CrawlSnapshotItem

    timestamps(type: :utc_datetime)
  end

  @doc "创建快照的 changeset"
  def changeset(snapshot, attrs) do
    snapshot
    |> cast(attrs, [:source_type, :crawled_at, :items_count])
    |> validate_required([:source_type, :crawled_at])
    |> validate_inclusion(:source_type, ["news", "newest"])
  end
end
