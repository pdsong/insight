defmodule Insight.Repo.Migrations.CreateUserInterestProfiles do
  use Ecto.Migration

  @moduledoc """
  用户兴趣画像表：记录用户对每个标签的兴趣权重。
  权重通过用户的 like/click/bookmark 等行为动态计算和更新。
  """

  def change do
    create table(:user_interest_profiles) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :tag_id, references(:tags, on_delete: :delete_all), null: false
      add :weight, :float, null: false, default: 0.0

      timestamps(type: :utc_datetime)
    end

    # 每个用户对每个标签只有一条画像记录
    create unique_index(:user_interest_profiles, [:user_id, :tag_id])
    create index(:user_interest_profiles, [:user_id])
  end
end
