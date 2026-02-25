defmodule Insight.Interactions.BlockedItem do
  @moduledoc """
  用户屏蔽规则 Schema。

  支持三种屏蔽类型：
  - "tag": 屏蔽特定标签（如不想看"加密货币"相关新闻）
  - "domain": 屏蔽特定域名（如不想看某个媒体的文章）
  - "keyword": 屏蔽包含特定关键词的新闻
  """
  use Ecto.Schema
  import Ecto.Changeset

  @valid_block_types ~w(tag domain keyword)

  schema "blocked_items" do
    belongs_to :user, Insight.Accounts.User

    field :block_type, :string
    field :value, :string

    timestamps(type: :utc_datetime)
  end

  @doc "创建屏蔽规则的 changeset"
  def changeset(blocked_item, attrs) do
    blocked_item
    |> cast(attrs, [:user_id, :block_type, :value])
    |> validate_required([:user_id, :block_type, :value])
    |> validate_inclusion(:block_type, @valid_block_types)
    |> unique_constraint([:user_id, :block_type, :value])
  end
end
