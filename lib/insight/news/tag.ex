defmodule Insight.News.Tag do
  @moduledoc """
  标签 Schema。

  标签分为两种类型：
  - "system": 系统自带标签（科技、AI、开源等），不可被用户修改
  - "user": 用户自定义标签，关联到创建者的 user_id
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "tags" do
    field :name, :string
    field :type, :string, default: "system"

    belongs_to :user, Insight.Accounts.User
    many_to_many :news_items, Insight.News.NewsItem, join_through: "news_tags"

    timestamps(type: :utc_datetime)
  end

  @doc "创建/更新标签的 changeset"
  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [:name, :type, :user_id])
    |> validate_required([:name, :type])
    |> validate_inclusion(:type, ["system", "user"])
  end
end
