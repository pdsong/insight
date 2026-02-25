defmodule Insight.Interactions.UserInteraction do
  @moduledoc """
  用户交互记录 Schema。

  统一记录用户对新闻的所有交互行为：
  - like: 点赞
  - dislike: 踩
  - click: 点击阅读
  - bookmark: 收藏/稍后再读
  - read: 已读标记

  `duration_seconds` 仅用于 click 类型，记录用户停留时长。
  """
  use Ecto.Schema
  import Ecto.Changeset

  @valid_actions ~w(like dislike click bookmark read)

  schema "user_interactions" do
    belongs_to :user, Insight.Accounts.User
    belongs_to :news_item, Insight.News.NewsItem

    field :action, :string
    field :duration_seconds, :integer

    timestamps(type: :utc_datetime)
  end

  @doc "创建交互记录的 changeset"
  def changeset(interaction, attrs) do
    interaction
    |> cast(attrs, [:user_id, :news_item_id, :action, :duration_seconds])
    |> validate_required([:user_id, :news_item_id, :action])
    |> validate_inclusion(:action, @valid_actions)
    |> unique_constraint([:user_id, :news_item_id, :action])
  end
end
