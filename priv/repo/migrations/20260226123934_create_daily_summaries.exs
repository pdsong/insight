defmodule Insight.Repo.Migrations.CreateDailySummaries do
  use Ecto.Migration

  def change do
    create table(:daily_summaries) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :date, :date, null: false
      add :content, :text
      add :status, :string, default: "pending", null: false

      timestamps(type: :utc_datetime)
    end

    create index(:daily_summaries, [:user_id])
    create unique_index(:daily_summaries, [:user_id, :date])
  end
end
