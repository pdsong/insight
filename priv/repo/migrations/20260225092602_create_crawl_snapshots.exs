defmodule Insight.Repo.Migrations.CreateCrawlSnapshots do
  use Ecto.Migration

  @moduledoc """
  爬取快照表：
  - crawl_snapshots: 每次爬取创建一条记录，记录爬取时间和类型
  - crawl_snapshot_items: 关联快照和新闻，记录该时刻每条新闻的排名、分数、评论数

  这种设计保留了每个整点时刻的新闻列表快照，同时新闻数据不重复存储。
  """

  def change do
    # 爬取快照主表
    create table(:crawl_snapshots) do
      add :source_type, :string, null: false
      add :crawled_at, :utc_datetime, null: false
      add :items_count, :integer, default: 0

      timestamps(type: :utc_datetime)
    end

    # 按类型和时间查询最新快照
    create index(:crawl_snapshots, [:source_type, :crawled_at])

    # 快照-新闻关联表
    create table(:crawl_snapshot_items) do
      add :crawl_snapshot_id, references(:crawl_snapshots, on_delete: :delete_all), null: false
      add :news_item_id, references(:news_items, on_delete: :delete_all), null: false
      add :rank, :integer
      add :score_at_crawl, :integer
      add :comments_count_at_crawl, :integer
    end

    # 同一快照中不会有重复的新闻
    create unique_index(:crawl_snapshot_items, [:crawl_snapshot_id, :news_item_id])
    create index(:crawl_snapshot_items, [:news_item_id])
  end
end
