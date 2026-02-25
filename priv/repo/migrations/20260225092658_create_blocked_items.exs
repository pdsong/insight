defmodule Insight.Repo.Migrations.CreateBlockedItems do
  use Ecto.Migration

  @moduledoc """
  用户屏蔽规则表：支持按标签、域名、关键词屏蔽新闻。
  """

  def change do
    create table(:blocked_items) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      # tag, domain, keyword
      add :block_type, :string, null: false
      add :value, :string, null: false

      timestamps(type: :utc_datetime)
    end

    # 同一用户不重复屏蔽相同类型和值
    create unique_index(:blocked_items, [:user_id, :block_type, :value])
    create index(:blocked_items, [:user_id])
  end
end
