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

  @doc "批量查询用户对一组新闻的交互状态，返回 %{news_item_id => MapSet<action>}"
  def list_interactions_for_news_ids(user_id, news_item_ids) when is_list(news_item_ids) do
    if user_id == nil || news_item_ids == [] do
      %{}
    else
      UserInteraction
      |> where([i], i.user_id == ^user_id and i.news_item_id in ^news_item_ids)
      |> select([i], {i.news_item_id, i.action})
      |> Repo.all()
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
      |> Map.new(fn {id, actions} -> {id, MapSet.new(actions)} end)
    end
  end

  @doc """
  切换 like/dislike，确保互斥：
  - 如果已经 like 再点 like → 取消 like
  - 如果已经 like 再点 dislike → 取消 like + 添加 dislike
  """
  def toggle_like_dislike(user_id, news_item_id, action) when action in ["like", "dislike"] do
    opposite = if action == "like", do: "dislike", else: "like"

    # 先删除对立的交互
    delete_interaction(user_id, news_item_id, opposite)

    # 再切换当前交互
    toggle_interaction(user_id, news_item_id, action)
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

  @doc "重新计算并更新某个用户的所有兴趣画像"
  def calculate_all_user_interest_profiles(user_id) do
    # 权重规则
    weight_map = %{
      "like" => 2.0,
      "bookmark" => 1.5,
      "read" => 1.0,
      "dislike" => -2.0
    }

    # 查询用户的所有交互及对应的新闻标签
    query =
      from ui in UserInteraction,
        join: nt in "news_tags",
        on: nt.news_item_id == ui.news_item_id,
        where: ui.user_id == ^user_id,
        # 可以限制在最近的行为，比如只看最近30天
        # where: ui.inserted_at >= datetime_add(^DateTime.utc_now(), -30, "day"),
        select: %{tag_id: nt.tag_id, action: ui.action}

    interactions = Repo.all(query)

    # 聚合每个标签的得分
    tag_scores =
      Enum.reduce(interactions, %{}, fn %{tag_id: tag_id, action: action}, acc ->
        score = Map.get(weight_map, action, 0.0)
        Map.update(acc, tag_id, score, &(&1 + score))
      end)

    # 清除旧的负分或零分（可选），这里我们直接全部更新或创建
    # 并且我们可以加一个阻尼/归一化，比如不要超过 100，不过简单起见直接保存。

    now = DateTime.utc_now(:second)

    entries =
      Enum.map(tag_scores, fn {tag_id, score} ->
        # 归一化得分：防止分数无限扩大，可以设置一个简单的阻尼或者上限
        # 此处使用简单的 clamp (-100 到 100)
        final_score = max(min(score, 100.0), -100.0)

        %{
          user_id: user_id,
          tag_id: tag_id,
          weight: final_score,
          inserted_at: now,
          updated_at: now
        }
      end)

    # 过滤掉低于 0 的标签（如果不想要负面画像）
    positive_entries = Enum.filter(entries, &(&1.weight > 0.1))

    # 先删除旧的
    Repo.delete_all(from p in UserInterestProfile, where: p.user_id == ^user_id)

    # 插入新的
    if positive_entries != [] do
      Repo.insert_all(UserInterestProfile, positive_entries)
    end

    :ok
  end
end
