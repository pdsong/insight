defmodule Insight.Repo.Migrations.CreateNewsItems do
  use Ecto.Migration

  @moduledoc """
  新闻主表：存储 HackerNews 上每条唯一的新闻。
  up_id 是 HN 上的原始 ID，作为唯一标识防止重复。
  title_zh / summary_zh / keywords 由 AI 后续填充。
  """

  def change do
    create table(:news_items) do
      # HN 原始字段
      add :up_id, :integer, null: false
      add :title, :string, null: false
      add :url, :string
      add :domain, :string
      add :hn_user, :string
      add :posted_at, :utc_datetime

      # AI 填充字段
      add :title_zh, :string
      add :summary_zh, :text
      add :keywords, :string

      timestamps(type: :utc_datetime)
    end

    # up_id 唯一索引，确保不重复入库
    create unique_index(:news_items, [:up_id])
    # 按发布时间查询的索引
    create index(:news_items, [:posted_at])
  end
end
