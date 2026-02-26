defmodule Insight.Feeds do
  @moduledoc """
  自定义阅读流领域的 Context 模块。

  提供自定义 Feed 的 CRUD 接口。
  """
  import Ecto.Query
  alias Insight.Repo
  alias Insight.Feeds.CustomFeed

  @doc "获取用户的所有自定义阅读流"
  def list_custom_feeds(user_id) do
    CustomFeed
    |> where([f], f.user_id == ^user_id)
    |> order_by([f], asc: f.name)
    |> Repo.all()
  end

  @doc "根据 ID 获取自定义阅读流"
  def get_custom_feed!(id), do: Repo.get!(CustomFeed, id)

  @doc "创建自定义阅读流"
  def create_custom_feed(attrs) do
    %CustomFeed{}
    |> CustomFeed.changeset(attrs)
    |> Repo.insert()
  end

  @doc "更新自定义阅读流"
  def update_custom_feed(%CustomFeed{} = feed, attrs) do
    feed
    |> CustomFeed.changeset(attrs)
    |> Repo.update()
  end

  @doc "删除自定义阅读流"
  def delete_custom_feed(%CustomFeed{} = feed), do: Repo.delete(feed)

  @doc "获取自定义阅读流的 changeset"
  def change_custom_feed(%CustomFeed{} = feed, attrs \\ %{}) do
    CustomFeed.changeset(feed, attrs)
  end

  @doc """
  根据自定义阅读流的 rules 查询新闻列表（分页）。

  ## rules 支持的键
  - `"tags"` — 标签名列表（包含任一标签即匹配）
  - `"keywords"` — 关键词列表（标题 LIKE 匹配任一关键词即匹配）
  - `"min_score"` — 最低 HN score（整数）

  ## 参数
  - `feed` — CustomFeed 结构体
  - `opts` — 分页选项 `:page`, `:per_page`
  """
  def query_feed(%CustomFeed{rules: rules}, opts \\ []) do
    alias Insight.News.{NewsItem, Tag}

    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 20)

    query = from(n in NewsItem, order_by: [desc: n.inserted_at])

    # 标签规则：包含任一指定标签
    tags = Map.get(rules, "tags", [])

    query =
      if tags != [] do
        matching_tag_ids =
          from(t in Tag,
            where: t.name in ^tags,
            select: t.id
          )

        matching_news_ids =
          from(nt in "news_tags",
            where: nt.tag_id in subquery(matching_tag_ids),
            select: nt.news_item_id
          )

        from(n in query, where: n.id in subquery(matching_news_ids))
      else
        query
      end

    # 关键词规则：标题包含任一关键词
    keywords = Map.get(rules, "keywords", [])

    query =
      if keywords != [] do
        Enum.reduce(keywords, nil, fn kw, acc ->
          pattern = "%#{kw}%"
          condition = dynamic([n], like(n.title, ^pattern) or like(n.title_zh, ^pattern))
          if acc, do: dynamic([n], ^acc or ^condition), else: condition
        end)
        |> then(fn conditions ->
          if conditions, do: from(n in query, where: ^conditions), else: query
        end)
      else
        query
      end

    total = Insight.Repo.aggregate(query, :count, :id)

    items =
      query
      |> offset(^((page - 1) * per_page))
      |> limit(^per_page)
      |> Insight.Repo.all()
      |> Insight.Repo.preload(:tags)

    %{
      items: items,
      page: page,
      per_page: per_page,
      total: total,
      total_pages: max(ceil(total / per_page), 1)
    }
  end
end
