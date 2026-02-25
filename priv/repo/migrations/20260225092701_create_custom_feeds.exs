defmodule Insight.Repo.Migrations.CreateCustomFeeds do
  use Ecto.Migration

  @moduledoc """
  自定义阅读流表：用户可以组合标签、关键词、分数阈值创建个性化的新闻流。
  rules 字段以 JSON 格式存储筛选规则。
  """

  def change do
    create table(:custom_feeds) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :name, :string, null: false
      # JSON 格式存储规则，如 {"tags": ["AI", "开源"], "min_score": 100}
      add :rules, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:custom_feeds, [:user_id])
  end
end
