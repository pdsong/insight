defmodule Insight.News.CrawlSnapshotItem do
  @moduledoc """
  快照-新闻关联 Schema。

  记录某次爬取快照中每条新闻的排名（rank）和该时刻的分数与评论数。
  这样既保留了每个整点的新闻列表快照，又能追踪新闻热度变化趋势。
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "crawl_snapshot_items" do
    belongs_to :crawl_snapshot, Insight.News.CrawlSnapshot
    belongs_to :news_item, Insight.News.NewsItem

    # 该新闻在列表中的排名位次
    field :rank, :integer
    # 该时刻的分数和评论数（随时间变化）
    field :score_at_crawl, :integer
    field :comments_count_at_crawl, :integer
  end

  @doc "创建快照关联条目的 changeset"
  def changeset(item, attrs) do
    item
    |> cast(attrs, [
      :crawl_snapshot_id,
      :news_item_id,
      :rank,
      :score_at_crawl,
      :comments_count_at_crawl
    ])
    |> validate_required([:crawl_snapshot_id, :news_item_id])
    |> unique_constraint([:crawl_snapshot_id, :news_item_id])
  end
end
