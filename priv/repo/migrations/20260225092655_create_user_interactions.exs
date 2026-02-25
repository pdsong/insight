defmodule Insight.Repo.Migrations.CreateUserInteractions do
  use Ecto.Migration

  @moduledoc """
  用户交互记录表：统一记录用户对新闻的所有交互行为。
  action 类型：like, dislike, click, bookmark, read
  duration_seconds 用于记录用户的阅读停留时长（用于兴趣画像计算）。
  """

  def change do
    create table(:user_interactions) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :news_item_id, references(:news_items, on_delete: :delete_all), null: false
      add :action, :string, null: false
      # 停留时长（秒），仅 click 类型使用
      add :duration_seconds, :integer

      timestamps(type: :utc_datetime)
    end

    # 同一用户对同一新闻的同一行为只记录一次（如 like/dislike）
    create unique_index(:user_interactions, [:user_id, :news_item_id, :action])
    create index(:user_interactions, [:user_id])
    create index(:user_interactions, [:news_item_id])
    # 按用户和行为类型查询
    create index(:user_interactions, [:user_id, :action])
  end
end
