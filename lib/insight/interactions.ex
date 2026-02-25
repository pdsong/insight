defmodule Insight.Interactions do
  @moduledoc """
  用户交互领域的 Context 模块。

  提供用户交互、屏蔽规则、兴趣画像相关的业务逻辑接口。
  """
  import Ecto.Query
  alias Insight.Repo
  alias Insight.Interactions.{UserInteraction, BlockedItem, UserInterestProfile}

  # ============================================================
  # 用户交互
  # ============================================================

  @doc "创建用户交互记录（like/dislike/click/bookmark/read）"
  def create_interaction(attrs) do
    %UserInteraction{}
    |> UserInteraction.changeset(attrs)
    |> Repo.insert()
  end

  @doc "删除用户交互记录（取消 like/bookmark 等）"
  def delete_interaction(user_id, news_item_id, action) do
    UserInteraction
    |> where(
      [i],
      i.user_id == ^user_id and i.news_item_id == ^news_item_id and i.action == ^action
    )
    |> Repo.delete_all()
  end

  @doc "切换交互状态（如已 like 则取消，未 like 则添加）"
  def toggle_interaction(user_id, news_item_id, action) do
    case get_interaction(user_id, news_item_id, action) do
      nil -> create_interaction(%{user_id: user_id, news_item_id: news_item_id, action: action})
      interaction -> Repo.delete(interaction)
    end
  end

  @doc "查询用户对某条新闻的特定交互"
  def get_interaction(user_id, news_item_id, action) do
    UserInteraction
    |> where(
      [i],
      i.user_id == ^user_id and i.news_item_id == ^news_item_id and i.action == ^action
    )
    |> Repo.one()
  end

  @doc "查询用户对某条新闻的所有交互类型"
  def list_user_interactions_for_news(user_id, news_item_id) do
    UserInteraction
    |> where([i], i.user_id == ^user_id and i.news_item_id == ^news_item_id)
    |> Repo.all()
  end

  @doc "查询用户的某类交互历史（如所有 like 记录）"
  def list_user_interactions_by_action(user_id, action) do
    UserInteraction
    |> where([i], i.user_id == ^user_id and i.action == ^action)
    |> order_by([i], desc: i.inserted_at)
    |> preload(:news_item)
    |> Repo.all()
  end

  @doc "检查新闻是否已读"
  def read?(user_id, news_item_id) do
    get_interaction(user_id, news_item_id, "read") != nil
  end

  @doc "批量标记已读"
  def mark_all_as_read(user_id, news_item_ids) do
    now = DateTime.utc_now(:second)

    entries =
      Enum.map(news_item_ids, fn id ->
        %{user_id: user_id, news_item_id: id, action: "read", inserted_at: now, updated_at: now}
      end)

    Repo.insert_all(UserInteraction, entries, on_conflict: :nothing)
  end

  # ============================================================
  # 屏蔽规则
  # ============================================================

  @doc "获取用户的所有屏蔽规则"
  def list_blocked_items(user_id) do
    BlockedItem
    |> where([b], b.user_id == ^user_id)
    |> order_by([b], desc: b.inserted_at)
    |> Repo.all()
  end

  @doc "创建屏蔽规则"
  def create_blocked_item(attrs) do
    %BlockedItem{}
    |> BlockedItem.changeset(attrs)
    |> Repo.insert()
  end

  @doc "删除屏蔽规则"
  def delete_blocked_item(%BlockedItem{} = item), do: Repo.delete(item)

  @doc "获取屏蔽规则"
  def get_blocked_item!(id), do: Repo.get!(BlockedItem, id)

  # ============================================================
  # 兴趣画像
  # ============================================================

  @doc "获取用户的兴趣画像（按权重降序）"
  def list_user_interest_profiles(user_id) do
    UserInterestProfile
    |> where([p], p.user_id == ^user_id)
    |> order_by([p], desc: p.weight)
    |> preload(:tag)
    |> Repo.all()
  end

  @doc "更新或创建兴趣画像条目"
  def upsert_interest_profile(user_id, tag_id, weight) do
    case Repo.get_by(UserInterestProfile, user_id: user_id, tag_id: tag_id) do
      nil ->
        %UserInterestProfile{}
        |> UserInterestProfile.changeset(%{user_id: user_id, tag_id: tag_id, weight: weight})
        |> Repo.insert()

      profile ->
        profile
        |> UserInterestProfile.changeset(%{weight: weight})
        |> Repo.update()
    end
  end
end
