defmodule Insight.News.DailySummaryGenerator do
  @moduledoc """
  每日新闻简报生成调度器。
  """
  require Logger
  alias Insight.News
  alias Insight.Interactions
  alias Insight.Accounts
  import Ecto.Query

  @doc """
  为系统中所有用户生成今日简报。
  如果某个用户已经生成完成（或正在生成），则跳过。
  """
  def generate_all_summaries do
    today = Date.utc_today()

    Accounts.list_users()
    |> Enum.each(fn user ->
      summary = News.get_daily_summary(user.id, today)

      if is_nil(summary) or summary.status == "failed" do
        Task.start(fn -> generate_for_user(user.id, today) end)
      end
    end)
  end

  @doc """
  为特定用户生成特定日期的简报。
  """
  def generate_for_user(user_id, date) do
    # 状态变更为 generating
    {:ok, _} = News.upsert_daily_summary(%{user_id: user_id, date: date, status: "generating"})

    try do
      # 1. 获取核心兴趣
      top_profiles = Interactions.list_user_interest_profiles(user_id) |> Enum.take(3)

      if top_profiles == [] do
        News.upsert_daily_summary(%{
          user_id: user_id,
          date: date,
          status: "completed",
          content: "今日暂无满足您兴趣偏好的抓取新闻。（您可能还没有收藏或点赞任何内容）"
        })
      else
        # 2. 获取最近 24 小时内匹配这些兴趣的新闻 (最多 15 篇)
        items = find_relevant_news(user_id, top_profiles)

        if items == [] do
          News.upsert_daily_summary(%{
            user_id: user_id,
            date: date,
            status: "completed",
            content: "今日暂无满足您核心兴趣标签的新闻推送。"
          })
        else
          # 3. 调用 AI 汇总
          case Insight.AI.DailySummarizer.generate_newsletter(items, top_profiles) do
            {:ok, content} ->
              News.upsert_daily_summary(%{
                user_id: user_id,
                date: date,
                status: "completed",
                content: content
              })

            {:error, _err} ->
              News.upsert_daily_summary(%{user_id: user_id, date: date, status: "failed"})
          end
        end
      end
    rescue
      err ->
        Logger.error("Failed to generate summary for user #{user_id}: #{inspect(err)}")
        News.upsert_daily_summary(%{user_id: user_id, date: date, status: "failed"})
    end
  end

  defp find_relevant_news(user_id, top_profiles) do
    if top_profiles == [] do
      []
    else
      tag_ids = Enum.map(top_profiles, & &1.tag.id)
      yesterday = DateTime.utc_now() |> DateTime.add(-24, :hour)

      # 查询关联标签并且在最近 24小时抓取的新闻
      query =
        from n in News.NewsItem,
          join: nt in "news_tags",
          on: nt.news_item_id == n.id,
          where: nt.tag_id in ^tag_ids and n.inserted_at >= ^yesterday,
          order_by: [desc: n.inserted_at],
          limit: 15,
          distinct: n.id

      # 过滤屏蔽的内容
      query = apply_blocking_filters(query, user_id)

      Insight.Repo.all(query)
    end
  end

  defp apply_blocking_filters(query, user_id) do
    alias Insight.Interactions.BlockedItem

    blocked_items =
      Insight.Repo.all(
        from b in BlockedItem,
          where: b.user_id == ^user_id
      )

    if blocked_items == [] do
      query
    else
      blocked_keywords = for %{block_type: "keyword", value: v} <- blocked_items, do: v
      blocked_domains = for %{block_type: "domain", value: v} <- blocked_items, do: v
      blocked_tags = for %{block_type: "tag", value: v} <- blocked_items, do: v

      query =
        if blocked_domains != [] do
          from(n in query, where: n.domain not in ^blocked_domains)
        else
          query
        end

      query =
        Enum.reduce(blocked_keywords, query, fn kw, q ->
          pattern = "%#{kw}%"

          from(n in q,
            where:
              not like(n.title, ^pattern) and
                (is_nil(n.title_zh) or not like(n.title_zh, ^pattern))
          )
        end)

      query =
        if blocked_tags != [] do
          blocked_tag_ids =
            from(t in Insight.News.Tag,
              where: t.name in ^blocked_tags,
              select: t.id
            )

          blocked_news_ids =
            from(nt in "news_tags",
              where: nt.tag_id in subquery(blocked_tag_ids),
              select: nt.news_item_id
            )

          from(n in query, where: n.id not in subquery(blocked_news_ids))
        else
          query
        end

      query
    end
  end
end
