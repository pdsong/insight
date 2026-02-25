defmodule Insight.Feeds.CustomFeed do
  @moduledoc """
  自定义阅读流 Schema。

  用户可以组合多种规则创建个性化的新闻流，例如：
  - 包含标签：AI, LLM
  - 最低分数：100
  - 排除关键词：crypto

  rules 以 JSON 格式存储，查询时动态解析为 Ecto 查询条件。
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "custom_feeds" do
    belongs_to :user, Insight.Accounts.User

    field :name, :string
    field :rules, :map, default: %{}

    timestamps(type: :utc_datetime)
  end

  @doc "创建/更新自定义阅读流的 changeset"
  def changeset(feed, attrs) do
    feed
    |> cast(attrs, [:user_id, :name, :rules])
    |> validate_required([:user_id, :name])
  end
end
