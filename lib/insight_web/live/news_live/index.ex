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
      |> assign(:source_type, "newest")
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
    # 默认为 "newest"，不再有 "全部" 选项
    source_type = params["source"] || "newest"
    search = params["search"] || ""
    feed_id = parse_int(params["feed"], nil)

    user_id = get_user_id(socket)

    # 如果指定了 feed，使用 feed 查询引擎；否则使用快照查询（按 crawl rank 排序）
    result =
      if feed_id do
        feed = Feeds.get_custom_feed!(feed_id)
        Feeds.query_feed(feed, page: page, per_page: @per_page)
      else
        News.list_snapshot_news(source_type, tag_id: tag_id, search: search, user_id: user_id)
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

    # 处理 AI 生成 (暂时注释掉)
    for item <- result.items, is_nil(ai_reasons[item.id]) do
      # if Map.get(item, :is_serendipity) do
      #   # 破圈推荐语
      #   Task.async(fn ->
      #     case Insight.AI.Recommender.generate_serendipity_reason(item) do
      #       {:ok, reason} -> {:ai_reason, item.id, reason}
      #       _ -> {:ai_reason, item.id, nil}
      #     end
      #   end)
      # else
      #   # 兴趣画像推荐语
      #   if top_profiles != [] do
      #     item_tag_names = Enum.map(item.tags, & &1.name)

      #     if Enum.any?(item_tag_names, &(&1 in profile_tag_names)) do
      #       Task.async(fn ->
      #         case Insight.AI.Recommender.generate_reason(item, top_profiles) do
      #           {:ok, reason} -> {:ai_reason, item.id, reason}
      #           _ -> {:ai_reason, item.id, nil}
      #         end
      #       end)
      #     end
      #   end
      # end
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
    source = if source == "", do: "newest", else: source
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
      Interactions.calculate_all_user_interest_profiles_async(user_id)

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
      Interactions.calculate_all_user_interest_profiles_async(user_id)

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
      Interactions.calculate_all_user_interest_profiles_async(user_id)

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
      <%!-- 页面标题 --%>
      <div class="text-center py-6">
        <h1
          class="text-5xl font-black tracking-wider bg-gradient-to-r from-cyan-400 via-blue-500 to-purple-600 bg-clip-text text-transparent drop-shadow-lg select-none"
          style="font-family: 'Inter', 'Outfit', system-ui, sans-serif; letter-spacing: 0.12em;"
        >
          INSIGHT
        </h1>
        <p class="text-sm opacity-50 mt-2 tracking-widest font-mono uppercase">
          HackerNews Intelligence · 共 {@news_result.total} 条
          <%= if @source_type do %>
            · {if @source_type == "news", do: "热门", else: "最新"}
          <% end %>
        </p>
      </div>

      <%!-- 来源类型切换 --%>
      <div class="flex items-center justify-center gap-3 flex-wrap">
        <button
          phx-click="filter_source"
          phx-value-source="newest"
          class={"btn transition-all duration-300 #{if @source_type == "newest" && is_nil(@active_feed_id), do: "btn-primary shadow-lg shadow-primary/30 scale-105", else: "btn-ghost border border-base-300 hover:border-primary/50"}"}
        >
          ⚡ 最新
        </button>
        <button
          phx-click="filter_source"
          phx-value-source="news"
          class={"btn transition-all duration-300 #{if @source_type == "news" && is_nil(@active_feed_id), do: "btn-primary shadow-lg shadow-primary/30 scale-105", else: "btn-ghost border border-base-300 hover:border-primary/50"}"}
        >
          🔥 热门
        </button>

        <%!-- 分隔线 --%>
        <div :if={@custom_feeds != []} class="divider divider-horizontal mx-0"></div>

        <%!-- 自定义 Feed Tab --%>
        <.link
          :for={feed <- @custom_feeds}
          patch={~p"/?feed=#{feed.id}"}
          class={"btn #{if @active_feed_id == feed.id, do: "btn-secondary shadow-lg shadow-secondary/30", else: "btn-ghost border border-base-300"}"}
        >
          📋 {feed.name}
        </.link>

        <%!-- 管理入口 --%>
        <.link
          :if={get_user_id_from_assigns(@current_scope) != nil}
          navigate={~p"/feeds"}
          class="btn btn-ghost btn-circle opacity-40 hover:opacity-100"
          title="管理阅读流"
        >
          <.icon name="hero-cog-6-tooth-mini" class="size-4" />
        </.link>
      </div>

      <%!-- 搜索框 --%>
      <div class="flex justify-center mt-4">
        <form phx-submit="search" class="join w-full max-w-md">
          <input
            type="text"
            name="search"
            value={@search}
            placeholder="搜索标题 / Search titles..."
            class="input input-bordered join-item w-full focus:border-primary/50 focus:shadow-lg focus:shadow-primary/10 transition-all"
            phx-debounce="300"
          />
          <button type="submit" class="btn btn-primary join-item">
            <.icon name="hero-magnifying-glass" class="size-5" />
          </button>
        </form>
      </div>

      <%!-- 标签筛选 --%>
      <div class="flex flex-wrap gap-2 justify-center mt-4">
        <button
          :for={tag <- @tags}
          phx-click="filter_tag"
          phx-value-tag-id={tag.id}
          class={"badge badge-lg cursor-pointer transition-all duration-200 hover:scale-105 font-medium #{if @selected_tag_id == tag.id, do: "badge-primary shadow-md shadow-primary/20", else: "badge-outline opacity-60 hover:opacity-100 hover:border-primary/40"}"}
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

      <%!-- 新闻卡片网格 --%>
      <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-3">
        <div
          :for={
            {item, idx} <-
              Enum.with_index(@news_result.items, 1)
          }
          class={"card border shadow-sm transition-all duration-200 hover:shadow-md hover:-translate-y-0.5 #{
            if(Map.get(item, :is_serendipity),
              do: "bg-gradient-to-br from-slate-900 via-purple-950 to-slate-900 border-purple-500/50 shadow-purple-500/20 shadow-md text-gray-100",
              else: "bg-base-100 border-base-300"
            )
          } #{if read?(item.id, @interactions), do: "opacity-50", else: ""}"}
        >
          <div class="card-body p-3 flex flex-col gap-2">
            <%!-- 序号 + 破圈标记 --%>
            <div class="flex items-center justify-between">
              <span class="badge badge-sm badge-primary font-mono font-bold">{idx}</span>
              <div
                :if={Map.get(item, :is_serendipity)}
                class="tooltip tooltip-left tooltip-primary max-w-xs"
                data-tip="🔥 破圈推荐：探索认知边界。这篇内容在你的日常阅读画像之外，但近期展现出极高的讨论价值。偶尔跳出信息茧房，遇见未知的精彩。"
              >
                <span class="badge badge-xs border border-cyan-400/80 bg-cyan-950/80 text-cyan-300 font-semibold shadow-[0_0_8px_rgba(34,211,238,0.4)] transition-all hover:scale-105">
                  <span class="mr-1">⚡</span> 破圈
                </span>
              </div>
            </div>

            <%!-- 标题 --%>
            <a
              href={item.url || "https://news.ycombinator.com/item?id=#{item.up_id}"}
              target="_blank"
              rel="noopener"
              class="font-medium text-sm leading-snug hover:text-primary transition-colors line-clamp-3"
              phx-click="mark_read"
              phx-value-news-id={item.id}
            >
              {item.title_zh || item.title}
            </a>

            <%!-- 原标题 --%>
            <p
              :if={item.title_zh && item.title_zh != ""}
              class="text-xs opacity-40 line-clamp-1 -mt-1"
            >
              {item.title}
            </p>

            <%!-- AI 推荐理由 --%>
            <div
              :if={@ai_reasons[item.id]}
              class="p-1.5 rounded bg-primary/5 border border-primary/10"
            >
              <p class="text-xs text-primary/80 line-clamp-2 leading-relaxed">
                ✨ {@ai_reasons[item.id]}
              </p>
            </div>

            <%!-- 弹性撑开 --%>
            <div class="flex-1"></div>

            <%!-- 元信息 --%>
            <div class="flex flex-wrap items-center gap-x-2 gap-y-0.5 text-xs opacity-50">
              <span :if={item.domain} class="truncate max-w-[120px]">{item.domain}</span>
              <a
                href={"https://news.ycombinator.com/item?id=#{item.up_id}"}
                target="_blank"
                rel="noopener"
                class="hover:text-primary transition-colors"
              >
                HN
              </a>
            </div>

            <%!-- 标签 --%>
            <div
              :if={item.tags != [] && item.tags != %Ecto.Association.NotLoaded{}}
              class="flex flex-wrap gap-1"
            >
              <span
                :for={tag <- item.tags}
                class="badge badge-xs badge-outline opacity-60"
              >
                {tag.name}
              </span>
            </div>

            <%!-- 操作按钮 --%>
            <div class="flex items-center justify-between border-t border-base-200 pt-2 -mb-1">
              <div class="flex items-center gap-0.5">
                <button
                  phx-click="toggle_reaction"
                  phx-value-news-id={item.id}
                  phx-value-action="like"
                  class={"btn btn-xs btn-circle btn-ghost #{if liked?(item.id, @interactions), do: "text-success", else: "opacity-40 hover:opacity-80"}"}
                  title="喜欢"
                >
                  <.icon name="hero-hand-thumb-up-mini" class="size-3" />
                </button>
                <button
                  phx-click="toggle_reaction"
                  phx-value-news-id={item.id}
                  phx-value-action="dislike"
                  class={"btn btn-xs btn-circle btn-ghost #{if disliked?(item.id, @interactions), do: "text-error", else: "opacity-40 hover:opacity-80"}"}
                  title="不喜欢"
                >
                  <.icon name="hero-hand-thumb-down-mini" class="size-3" />
                </button>
              </div>
              <div class="flex items-center gap-0.5">
                <button
                  phx-click="toggle_bookmark"
                  phx-value-news-id={item.id}
                  class={"btn btn-xs btn-circle btn-ghost #{if bookmarked?(item.id, @interactions), do: "text-warning", else: "opacity-40 hover:opacity-80"}"}
                  title={if bookmarked?(item.id, @interactions), do: "取消收藏", else: "收藏"}
                >
                  <.icon
                    name={
                      if bookmarked?(item.id, @interactions),
                        do: "hero-bookmark-solid",
                        else: "hero-bookmark"
                    }
                    class="size-3"
                  />
                </button>
                <span
                  :if={read?(item.id, @interactions)}
                  class="opacity-30"
                  title="已读"
                >
                  <.icon name="hero-eye-slash" class="size-3" />
                </span>
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
