defmodule Insight.News.DailySummary do
  @moduledoc """
  个人的专属每日新闻简报。
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "daily_summaries" do
    field :date, :date
    field :content, :string
    field :status, :string, default: "pending"

    belongs_to :user, Insight.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(summary, attrs) do
    summary
    |> cast(attrs, [:date, :content, :status, :user_id])
    |> validate_required([:date, :user_id, :status])
    |> validate_inclusion(:status, ["pending", "generating", "completed", "failed"])
    |> unique_constraint([:user_id, :date])
  end
end
