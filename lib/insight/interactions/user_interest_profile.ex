defmodule Insight.Interactions.UserInterestProfile do
  @moduledoc """
  用户兴趣画像 Schema。

  记录每个用户对每个标签的兴趣权重。权重通过以下行为动态计算：
  - like: +2.0
  - click: +1.0
  - bookmark: +1.5
  - dislike: -2.0

  权重由定时任务周期性更新，用于个性化推荐和日报生成。
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_interest_profiles" do
    belongs_to :user, Insight.Accounts.User
    belongs_to :tag, Insight.News.Tag

    field :weight, :float, default: 0.0

    timestamps(type: :utc_datetime)
  end

  @doc "创建/更新兴趣画像的 changeset"
  def changeset(profile, attrs) do
    profile
    |> cast(attrs, [:user_id, :tag_id, :weight])
    |> validate_required([:user_id, :tag_id, :weight])
    |> unique_constraint([:user_id, :tag_id])
  end
end
