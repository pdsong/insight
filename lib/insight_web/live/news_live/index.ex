defmodule InsightWeb.NewsLive.Index do
  @moduledoc """
  新闻列表 LiveView。

  首页：展示已爬取的 HN 新闻，支持按标签/来源筛选、搜索和分页。
  已登录用户可对新闻进行 Like/Dislike 操作。
  """
  use InsightWeb, :live_view
  alias Insight.News
  alias Insight.Interactions
  alias Insight.Feeds

  @per_page 20

  @impl true
  def mount(_params, _session, socket) do
    tags = News.list_system_tags()
    user_id = get_user_id(socket)
    custom_feeds = if user_id, do: Feeds.list_custom_feeds(user_id), else: []

    socket =
      socket
      |> assign(:page_title, "新闻")
      |> assign(:tags, tags)
      |> assign(:selected_tag_id, nil)
      |> assign(:source_type, nil)
      |> assign(:search, "")
      |> assign(:page, 1)
      |> assign(:interactions, %{})
      |> assign(:custom_feeds, custom_feeds)
      |> assign(:active_feed_id, nil)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    page = parse_int(params["page"], 1)
    tag_id = parse_int(params["tag"], nil)
    source_type = params["source"]
    search = params["search"] || ""
    feed_id = parse_int(params["feed"], nil)

    user_id = get_user_id(socket)

    # 如果指定了 feed，使用 feed 查询引擎；否则使用默认查询
    result =
      if feed_id do
        feed = Feeds.get_custom_feed!(feed_id)
        Feeds.query_feed(feed, page: page, per_page: @per_page)
      else
        News.list_news_paginated(
          page: page,
          per_page: @per_page,
          tag_id: tag_id,
          source_type: source_type,
          search: search,
          user_id: user_id
        )
      end

    news_ids = Enum.map(result.items, & &1.id)
    interactions = Interactions.list_interactions_for_news_ids(user_id, news_ids)

    # 动态兴趣画像 & 推荐理由
    top_profiles =
      if user_id, do: Interactions.list_user_interest_profiles(user_id) |> Enum.take(3), else: []

    ai_reasons = socket.assigns[:ai_reasons] || %{}

    profile_tag_names = Enum.map(top_profiles, & &1.tag.name)
    profile_tag_ids = Enum.map(top_profiles, & &1.tag.id)

    # 每天安插的"破圈"文章（只在首页第1页，并且没有特定搜索或过滤时展示）
    show_serendipity? = user_id && page == 1 && is_nil(tag_id) && search == "" && is_nil(feed_id)

    serendipity_items =
      if show_serendipity? do
        News.fetch_serendipity_news(user_id, profile_tag_ids, news_ids, 2)
        |> Enum.map(&Map.put(&1, :is_serendipity, true))
      else
        []
      end

    # 将破圈文章随机或定点插入到信息流中 (比如第 3 个和第 7 个位置)
    stream_items =
      result.items
      |> Enum.map(&Map.put(&1, :is_serendipity, false))

    stream_items =
      case serendipity_items do
        [s1, s2] ->
          stream_items
          |> List.insert_at(min(3, length(stream_items)), s1)
          |> List.insert_at(min(7, length(stream_items) + 1), s2)

        [s1] ->
          stream_items
          |> List.insert_at(min(3, length(stream_items)), s1)

        _ ->
          stream_items
      end

    result = %{result | items: stream_items}

    # 处理 AI 生成
    for item <- result.items, is_nil(ai_reasons[item.id]) do
      if Map.get(item, :is_serendipity) do
        # 破圈推荐语
        Task.async(fn ->
          case Insight.AI.Recommender.generate_serendipity_reason(item) do
            {:ok, reason} -> {:ai_reason, item.id, reason}
            _ -> {:ai_reason, item.id, nil}
          end
        end)
      else
        # 兴趣画像推荐语
        if top_profiles != [] do
          item_tag_names = Enum.map(item.tags, & &1.name)

          if Enum.any?(item_tag_names, &(&1 in profile_tag_names)) do
            Task.async(fn ->
              case Insight.AI.Recommender.generate_reason(item, top_profiles) do
                {:ok, reason} -> {:ai_reason, item.id, reason}
                _ -> {:ai_reason, item.id, nil}
              end
            end)
          end
        end
      end
    end

    socket =
      socket
      |> assign(:page, page)
      |> assign(:selected_tag_id, tag_id)
      |> assign(:source_type, source_type)
      |> assign(:search, search)
      |> assign(:news_result, result)
      |> assign(:interactions, interactions)
      |> assign(:active_feed_id, feed_id)
      |> assign(:ai_reasons, ai_reasons)

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_source", %{"source" => source}, socket) do
    source = if source == "", do: nil, else: source
    {:noreply, push_patch(socket, to: build_path(socket, source_type: source, page: 1))}
  end

  @impl true
  def handle_event("filter_tag", %{"tag-id" => tag_id}, socket) do
    tag_id = parse_int(tag_id, nil)
    tag_id = if tag_id == socket.assigns.selected_tag_id, do: nil, else: tag_id
    {:noreply, push_patch(socket, to: build_path(socket, tag_id: tag_id, page: 1))}
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    {:noreply, push_patch(socket, to: build_path(socket, search: search, page: 1))}
  end

  @impl true
  def handle_event("goto_page", %{"page" => page}, socket) do
    {:noreply, push_patch(socket, to: build_path(socket, page: parse_int(page, 1)))}
  end

  @impl true
  def handle_event("toggle_reaction", %{"news-id" => news_id_str, "action" => action}, socket) do
    user_id = get_user_id(socket)

    if user_id do
      news_id = String.to_integer(news_id_str)
      Interactions.toggle_like_dislike(user_id, news_id, action)

      # 异步更新兴趣画像
      Task.start(fn -> Interactions.calculate_all_user_interest_profiles(user_id) end)

      {:noreply, refresh_interactions(socket, user_id, [news_id])}
    else
      {:noreply, put_flash(socket, :info, "请先登录后再操作")}
    end
  end

  @impl true
  def handle_event("toggle_bookmark", %{"news-id" => news_id_str}, socket) do
    user_id = get_user_id(socket)

    if user_id do
      news_id = String.to_integer(news_id_str)
      Interactions.toggle_interaction(user_id, news_id, "bookmark")

      # 异步更新兴趣画像
      Task.start(fn -> Interactions.calculate_all_user_interest_profiles(user_id) end)

      {:noreply, refresh_interactions(socket, user_id, [news_id])}
    else
      {:noreply, put_flash(socket, :info, "请先登录后再操作")}
    end
  end

  @impl true
  def handle_event("mark_read", %{"news-id" => news_id_str}, socket) do
    user_id = get_user_id(socket)

    if user_id do
      news_id = String.to_integer(news_id_str)
      # 只添加，不切换
      unless has_action?(news_id, socket.assigns.interactions, "read") do
        Interactions.create_interaction(%{user_id: user_id, news_item_id: news_id, action: "read"})
      end

      # 异步更新兴趣画像（虽然 read 权重小，但也算隐式交互）
      Task.start(fn -> Interactions.calculate_all_user_interest_profiles(user_id) end)

      {:noreply, refresh_interactions(socket, user_id, [news_id])}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("mark_all_read", _params, socket) do
    user_id = get_user_id(socket)

    if user_id do
      news_ids = Enum.map(socket.assigns.news_result.items, & &1.id)
      Interactions.mark_all_as_read(user_id, news_ids)
      {:noreply, refresh_interactions(socket, user_id, news_ids)}
    else
      {:noreply, put_flash(socket, :info, "请先登录后再操作")}
    end
  end

  @impl true
  def handle_info({ref, {:ai_reason, news_id, reason}}, socket) when is_reference(ref) do
    Process.demonitor(ref, [:flush])
    ai_reasons = Map.put(socket.assigns.ai_reasons, news_id, reason)
    {:noreply, assign(socket, :ai_reasons, ai_reasons)}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket) do
    {:noreply, socket}
  end

  # ============================================================
  # 渲染
  # ============================================================

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <%!-- 页面标题和搜索 --%>
      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 class="text-2xl font-bold tracking-tight">新闻</h1>
          <p class="text-sm opacity-60 mt-1">
            共 {@news_result.total} 条
            <%= if @source_type do %>
              · {if @source_type == "news", do: "热门", else: "最新"}
            <% end %>
          </p>
        </div>
        <form phx-submit="search" class="flex gap-2">
          <input
            type="text"
            name="search"
            value={@search}
            placeholder="搜索标题..."
            class="input input-bordered input-sm w-48"
            phx-debounce="300"
          />
          <button type="submit" class="btn btn-sm btn-ghost">
            <.icon name="hero-magnifying-glass" class="size-4" />
          </button>
        </form>
      </div>

      <%!-- 来源类型切换 --%>
      <div class="flex items-center gap-2 flex-wrap">
        <button
          phx-click="filter_source"
          phx-value-source=""
          class={"btn btn-sm #{if is_nil(@source_type) && is_nil(@active_feed_id), do: "btn-primary", else: "btn-ghost"}"}
        >
          全部
        </button>
        <button
          phx-click="filter_source"
          phx-value-source="news"
          class={"btn btn-sm #{if @source_type == "news" && is_nil(@active_feed_id), do: "btn-primary", else: "btn-ghost"}"}
        >
          🔥 热门
        </button>
        <button
          phx-click="filter_source"
          phx-value-source="newest"
          class={"btn btn-sm #{if @source_type == "newest" && is_nil(@active_feed_id), do: "btn-primary", else: "btn-ghost"}"}
        >
          ⚡ 最新
        </button>

        <%!-- 分隔线 --%>
        <div :if={@custom_feeds != []} class="divider divider-horizontal mx-0"></div>

        <%!-- 自定义 Feed Tab --%>
        <.link
          :for={feed <- @custom_feeds}
          patch={~p"/?feed=#{feed.id}"}
          class={"btn btn-sm #{if @active_feed_id == feed.id, do: "btn-secondary", else: "btn-ghost"}"}
        >
          📋 {feed.name}
        </.link>

        <%!-- 管理入口 --%>
        <.link
          :if={get_user_id_from_assigns(@current_scope) != nil}
          navigate={~p"/feeds"}
          class="btn btn-sm btn-ghost opacity-50 hover:opacity-100"
          title="管理阅读流"
        >
          <.icon name="hero-cog-6-tooth-mini" class="size-3.5" />
        </.link>
      </div>

      <%!-- 标签筛选 --%>
      <div class="flex flex-wrap gap-1.5">
        <button
          :for={tag <- @tags}
          phx-click="filter_tag"
          phx-value-tag-id={tag.id}
          class={"badge cursor-pointer transition-all duration-200 hover:scale-105 #{if @selected_tag_id == tag.id, do: "badge-primary", else: "badge-outline opacity-70 hover:opacity-100"}"}
        >
          {tag.name}
        </button>
      </div>

      <%!-- 一键标记已读 --%>
      <div
        :if={get_user_id_from_assigns(@current_scope) && @news_result.items != []}
        class="flex justify-end"
      >
        <button phx-click="mark_all_read" class="btn btn-xs btn-ghost opacity-60 hover:opacity-100">
          <.icon name="hero-check-circle-mini" class="size-3.5" /> 全部标为已读
        </button>
      </div>

      <%!-- 新闻列表 --%>
      <div class="space-y-3">
        <div
          :for={item <- @news_result.items}
          class={"card transition-colors duration-200 cursor-default #{
            if(Map.get(item, :is_serendipity),
              do: "bg-gradient-to-r from-purple-100/50 to-pink-100/50 border border-purple-200 hover:from-purple-200/50 hover:to-pink-200/50 shadow-sm",
              else: "bg-base-200/50 hover:bg-base-200"
            )
          } #{if read?(item.id, @interactions), do: "opacity-50", else: ""}"}
        >
          <div class="card-body p-4 relative">
            <%!-- 破圈标记 --%>
            <div :if={Map.get(item, :is_serendipity)} class="absolute top-3 right-3">
              <span class="badge badge-sm bg-gradient-to-r from-purple-500 to-pink-500 text-white border-0 shadow-sm">
                <.icon name="hero-sparkles-mini" class="size-3 mr-1" /> 破圈推荐
              </span>
            </div>

            <div class="flex items-start gap-3">
              <%!-- Like/Dislike 按钮 --%>
              <div class="flex flex-col items-center gap-1 pt-0.5 shrink-0">
                <button
                  phx-click="toggle_reaction"
                  phx-value-news-id={item.id}
                  phx-value-action="like"
                  class={"btn btn-xs btn-circle transition-all duration-200 #{if liked?(item.id, @interactions), do: "btn-success text-success-content scale-110", else: "btn-ghost opacity-50 hover:opacity-100"}"}
                  title="喜欢"
                >
                  <.icon name="hero-hand-thumb-up-mini" class="size-3.5" />
                </button>
                <button
                  phx-click="toggle_reaction"
                  phx-value-news-id={item.id}
                  phx-value-action="dislike"
                  class={"btn btn-xs btn-circle transition-all duration-200 #{if disliked?(item.id, @interactions), do: "btn-error text-error-content scale-110", else: "btn-ghost opacity-50 hover:opacity-100"}"}
                  title="不喜欢"
                >
                  <.icon name="hero-hand-thumb-down-mini" class="size-3.5" />
                </button>
              </div>

              <%!-- 主内容 --%>
              <div class="flex-1 min-w-0">
                <a
                  href={item.url || "https://news.ycombinator.com/item?id=#{item.up_id}"}
                  target="_blank"
                  rel="noopener"
                  class="font-medium hover:text-primary transition-colors line-clamp-2 text-sm"
                >
                  {item.title_zh || item.title}
                </a>

                <%!-- 原标题 --%>
                <p
                  :if={item.title_zh && item.title_zh != ""}
                  class="text-xs opacity-40 mt-0.5 line-clamp-1"
                >
                  {item.title}
                </p>

                <%!-- 摘要 --%>
                <p
                  :if={item.summary_zh && item.summary_zh != ""}
                  class="text-xs opacity-60 mt-1.5 line-clamp-2"
                >
                  {item.summary_zh}
                </p>

                <%!-- AI 推荐理由 --%>
                <div
                  :if={@ai_reasons[item.id]}
                  class="mt-2.5 p-2 rounded-md bg-gradient-to-r from-primary/10 to-secondary/10 border border-primary/20 flex items-start gap-2"
                >
                  <.icon name="hero-sparkles-solid" class="size-4 text-primary shrink-0 mt-0.5" />
                  <p class="text-xs font-medium text-primary/90 leading-relaxed">
                    {@ai_reasons[item.id]}
                  </p>
                </div>

                <%!-- 元信息 --%>
                <div class="flex flex-wrap items-center gap-x-3 gap-y-1 mt-2 text-xs opacity-50">
                  <span :if={item.domain} class="flex items-center gap-1">
                    <.icon name="hero-globe-alt-mini" class="size-3" />
                    {item.domain}
                  </span>
                  <span :if={item.hn_user} class="flex items-center gap-1">
                    <.icon name="hero-user-mini" class="size-3" />
                    {item.hn_user}
                  </span>
                  <a
                    href={"https://news.ycombinator.com/item?id=#{item.up_id}"}
                    target="_blank"
                    rel="noopener"
                    class="flex items-center gap-1 hover:text-primary transition-colors"
                  >
                    <.icon name="hero-chat-bubble-left-mini" class="size-3" /> HN
                  </a>
                </div>

                <%!-- 标签 --%>
                <%!-- 标签 + 操作 --%>
                <div class="flex items-center gap-2 mt-2">
                  <div
                    :if={item.tags != [] && item.tags != %Ecto.Association.NotLoaded{}}
                    class="flex flex-wrap gap-1 flex-1"
                  >
                    <span
                      :for={tag <- item.tags}
                      class="badge badge-xs badge-outline opacity-60"
                    >
                      {tag.name}
                    </span>
                  </div>
                  <div class="flex items-center gap-1 shrink-0">
                    <button
                      phx-click="toggle_bookmark"
                      phx-value-news-id={item.id}
                      class={"btn btn-xs btn-ghost transition-all duration-200 #{if bookmarked?(item.id, @interactions), do: "text-warning opacity-100", else: "opacity-40 hover:opacity-80"}"}
                      title={if bookmarked?(item.id, @interactions), do: "取消收藏", else: "稍后再读"}
                    >
                      <.icon
                        name={
                          if bookmarked?(item.id, @interactions),
                            do: "hero-bookmark-solid",
                            else: "hero-bookmark"
                        }
                        class="size-3.5"
                      />
                    </button>
                    <button
                      :if={!read?(item.id, @interactions)}
                      phx-click="mark_read"
                      phx-value-news-id={item.id}
                      class="btn btn-xs btn-ghost opacity-40 hover:opacity-80"
                      title="标为已读"
                    >
                      <.icon name="hero-eye" class="size-3.5" />
                    </button>
                    <span
                      :if={read?(item.id, @interactions)}
                      class="text-xs opacity-30"
                      title="已读"
                    >
                      <.icon name="hero-eye-slash" class="size-3.5" />
                    </span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <%!-- 空状态 --%>
        <div :if={@news_result.items == []} class="text-center py-16 opacity-40">
          <.icon name="hero-inbox" class="size-12 mx-auto mb-4" />
          <p class="text-lg">暂无新闻</p>
          <p class="text-sm mt-1">爬虫尚未抓取数据，请运行 <code>mix insight.crawl</code></p>
        </div>
      </div>

      <%!-- 分页 --%>
      <div :if={@news_result.total_pages > 1} class="flex justify-center gap-2 pt-4">
        <button
          :if={@page > 1}
          phx-click="goto_page"
          phx-value-page={@page - 1}
          class="btn btn-sm btn-ghost"
        >
          ← 上一页
        </button>
        <span class="btn btn-sm btn-disabled">
          {@page} / {@news_result.total_pages}
        </span>
        <button
          :if={@page < @news_result.total_pages}
          phx-click="goto_page"
          phx-value-page={@page + 1}
          class="btn btn-sm btn-ghost"
        >
          下一页 →
        </button>
      </div>
    </div>
    """
  end

  # ============================================================
  # 私有函数
  # ============================================================

  defp get_user_id(socket) do
    case socket.assigns[:current_scope] do
      %{user: %{id: id}} -> id
      _ -> nil
    end
  end

  defp has_action?(news_id, interactions, action) do
    case Map.get(interactions, news_id) do
      nil -> false
      actions -> MapSet.member?(actions, action)
    end
  end

  defp liked?(news_id, interactions), do: has_action?(news_id, interactions, "like")
  defp disliked?(news_id, interactions), do: has_action?(news_id, interactions, "dislike")
  defp bookmarked?(news_id, interactions), do: has_action?(news_id, interactions, "bookmark")
  defp read?(news_id, interactions), do: has_action?(news_id, interactions, "read")

  defp get_user_id_from_assigns(nil), do: nil
  defp get_user_id_from_assigns(%{user: %{id: id}}), do: id
  defp get_user_id_from_assigns(_), do: nil

  defp refresh_interactions(socket, user_id, news_ids) do
    updated = Interactions.list_interactions_for_news_ids(user_id, news_ids)
    # Merge updated, but remove entries that now have no interactions
    interactions =
      Enum.reduce(news_ids, socket.assigns.interactions, fn id, acc ->
        case Map.get(updated, id) do
          nil -> Map.delete(acc, id)
          set -> Map.put(acc, id, set)
        end
      end)

    assign(socket, :interactions, interactions)
  end

  defp build_path(socket, overrides) do
    params =
      %{
        page: Keyword.get(overrides, :page, socket.assigns.page),
        tag: Keyword.get(overrides, :tag_id, socket.assigns.selected_tag_id),
        source: Keyword.get(overrides, :source_type, socket.assigns.source_type),
        search: Keyword.get(overrides, :search, socket.assigns.search)
      }
      |> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" or v == 1 end)
      |> Map.new()

    case params do
      p when p == %{} -> ~p"/"
      _ -> ~p"/?#{params}"
    end
  end

  defp parse_int(nil, default), do: default
  defp parse_int("", default), do: default

  defp parse_int(str, default) when is_binary(str) do
    case Integer.parse(str) do
      {n, _} -> n
      :error -> default
    end
  end

  defp parse_int(n, _default) when is_integer(n), do: n
end
