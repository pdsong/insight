defmodule Insight.Interactions.Stats do
  @moduledoc """
  用户交互数据统计与成就计算。
  用于支撑 T17 技术雷达展示。
  """
  import Ecto.Query
  alias Insight.Repo
  alias Insight.Interactions.UserInteraction, as: Interaction

  @doc """
  获取用户阅读偏好的标签分布（用于绘制雷达图）。
  返回 `{tag_name, count}` 的列表，取最重要的前 6 个维度拼装为雷达图。
  """
  def get_tag_distribution(user_id) do
    query =
      from i in Interaction,
        join: nt in "news_tags",
        on: nt.news_item_id == i.news_item_id,
        join: t in "tags",
        on: nt.tag_id == t.id,
        where: i.user_id == ^user_id,
        group_by: t.name,
        select: %{name: t.name, score: count(i.id)},
        order_by: [desc: count(i.id)],
        limit: 6

    Repo.all(query)
  end

  @doc """
  计算用户的阅读成就称号和统计数据。
  """
  def get_user_achievements(user_id) do
    total_reads =
      Repo.aggregate(
        from(i in Interaction, where: i.user_id == ^user_id and i.action == "read"),
        :count
      ) || 0

    total_likes =
      Repo.aggregate(
        from(i in Interaction, where: i.user_id == ^user_id and i.action == "like"),
        :count
      ) || 0

    total_bookmarks =
      Repo.aggregate(
        from(i in Interaction, where: i.user_id == ^user_id and i.action == "bookmark"),
        :count
      ) || 0

    titles = []

    titles = if total_reads >= 5, do: ["初级探索者" | titles], else: titles
    titles = if total_reads >= 50, do: ["硅谷观察家" | titles], else: titles
    titles = if total_likes >= 10, do: ["点赞狂魔" | titles], else: titles
    titles = if total_bookmarks >= 5, do: ["知识收藏家" | titles], else: titles

    titles = if titles == [], do: ["潜水新手"], else: titles

    %{
      reads: total_reads,
      likes: total_likes,
      bookmarks: total_bookmarks,
      titles: Enum.reverse(titles)
    }
  end

  @doc """
  Story Arc Tracker ("还记得吗")
  随机获取用户过去收藏或点赞的 1 篇文章，并作为"记忆回顾"内容。
  """
  def get_memory_arc(user_id) do
    # 理想状态是 -7 days，但为了测试方便使用 -24 小时或所有历史
    past = DateTime.utc_now() |> DateTime.add(-24, :hour)

    query =
      from i in Interaction,
        join: n in Insight.News.NewsItem,
        on: i.news_item_id == n.id,
        where:
          i.user_id == ^user_id and i.action in ["bookmark", "like"] and i.inserted_at < ^past,
        order_by: fragment("RANDOM()"),
        limit: 1,
        select: n

    # SQLite 中的 RANDOM() 支持在 Ecto 直接用 fragment
    item = Repo.one(query)

    # 如果没有 24 小时前的，就随机任何一篇
    if is_nil(item) do
      backup_query =
        from i in Interaction,
          join: n in Insight.News.NewsItem,
          on: i.news_item_id == n.id,
          where: i.user_id == ^user_id and i.action in ["bookmark", "like"],
          order_by: fragment("RANDOM()"),
          limit: 1,
          select: n

      Repo.one(backup_query)
    else
      item
    end
  end
end
