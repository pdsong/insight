defmodule InsightWeb.FeedLive.Index do
  @moduledoc """
  自定义阅读流管理 LiveView。

  用户可创建、编辑、删除自定义 Feed，
  每个 Feed 通过 rules（标签 + 关键词）筛选新闻。
  """
  use InsightWeb, :live_view
  alias Insight.Feeds
  alias Insight.News

  @impl true
  def mount(_params, _session, socket) do
    user_id = get_user_id(socket)
    tags = News.list_system_tags() ++ News.list_user_tags(user_id)

    socket =
      socket
      |> assign(:page_title, "自定义阅读流")
      |> assign(:feeds, Feeds.list_custom_feeds(user_id))
      |> assign(:tags, tags)
      |> assign(:editing_feed, nil)
      |> assign(:form_name, "")
      |> assign(:form_tags, [])
      |> assign(:form_keywords, "")

    {:ok, socket}
  end

  @impl true
  def handle_event("new_feed", _params, socket) do
    socket =
      socket
      |> assign(:editing_feed, :new)
      |> assign(:form_name, "")
      |> assign(:form_tags, [])
      |> assign(:form_keywords, "")

    {:noreply, socket}
  end

  @impl true
  def handle_event("edit_feed", %{"id" => id}, socket) do
    feed = Feeds.get_custom_feed!(id)
    tags = Map.get(feed.rules, "tags", [])
    keywords = Map.get(feed.rules, "keywords", []) |> Enum.join(", ")

    socket =
      socket
      |> assign(:editing_feed, feed)
      |> assign(:form_name, feed.name)
      |> assign(:form_tags, tags)
      |> assign(:form_keywords, keywords)

    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel_edit", _params, socket) do
    {:noreply, assign(socket, :editing_feed, nil)}
  end

  @impl true
  def handle_event("toggle_tag", %{"tag" => tag_name}, socket) do
    tags = socket.assigns.form_tags

    tags =
      if tag_name in tags do
        List.delete(tags, tag_name)
      else
        [tag_name | tags]
      end

    {:noreply, assign(socket, :form_tags, tags)}
  end

  @impl true
  def handle_event("save_feed", %{"name" => name, "keywords" => keywords_str}, socket) do
    user_id = get_user_id(socket)
    name = String.trim(name)

    keywords =
      keywords_str
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    rules = %{
      "tags" => socket.assigns.form_tags,
      "keywords" => keywords
    }

    result =
      case socket.assigns.editing_feed do
        :new ->
          Feeds.create_custom_feed(%{user_id: user_id, name: name, rules: rules})

        %Feeds.CustomFeed{} = feed ->
          Feeds.update_custom_feed(feed, %{name: name, rules: rules})
      end

    case result do
      {:ok, _} ->
        socket =
          socket
          |> assign(:feeds, Feeds.list_custom_feeds(user_id))
          |> assign(:editing_feed, nil)
          |> put_flash(:info, "阅读流「#{name}」已保存")

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "保存失败")}
    end
  end

  @impl true
  def handle_event("delete_feed", %{"id" => id}, socket) do
    feed = Feeds.get_custom_feed!(id)
    {:ok, _} = Feeds.delete_custom_feed(feed)
    user_id = get_user_id(socket)

    socket =
      socket
      |> assign(:feeds, Feeds.list_custom_feeds(user_id))
      |> put_flash(:info, "已删除「#{feed.name}」")

    {:noreply, socket}
  end

  # ============================================================
  # 渲染
  # ============================================================

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-bold tracking-tight">自定义阅读流</h1>
          <p class="text-sm opacity-60 mt-1">组合标签和关键词，创建专属新闻流</p>
        </div>
        <button :if={is_nil(@editing_feed)} phx-click="new_feed" class="btn btn-sm btn-primary">
          <.icon name="hero-plus-mini" class="size-4" /> 创建
        </button>
      </div>

      <%!-- 编辑/创建表单 --%>
      <div :if={@editing_feed} class="card bg-base-200/50">
        <div class="card-body p-5 space-y-4">
          <h2 class="font-semibold">
            {if @editing_feed == :new, do: "创建阅读流", else: "编辑阅读流"}
          </h2>

          <form phx-submit="save_feed" class="space-y-4">
            <%!-- 名称 --%>
            <div>
              <label class="label text-xs font-medium">名称</label>
              <input
                type="text"
                name="name"
                value={@form_name}
                placeholder="如：AI 前沿"
                class="input input-bordered input-sm w-full max-w-xs"
                required
              />
            </div>

            <%!-- 标签选择 --%>
            <div>
              <label class="label text-xs font-medium">包含标签（点选）</label>
              <div class="flex flex-wrap gap-1.5 mt-1">
                <button
                  :for={tag <- @tags}
                  type="button"
                  phx-click="toggle_tag"
                  phx-value-tag={tag.name}
                  class={"badge cursor-pointer transition-all duration-200 #{if tag.name in @form_tags, do: "badge-primary", else: "badge-outline opacity-60 hover:opacity-100"}"}
                >
                  {tag.name}
                </button>
              </div>
            </div>

            <%!-- 关键词 --%>
            <div>
              <label class="label text-xs font-medium">关键词（逗号分隔）</label>
              <input
                type="text"
                name="keywords"
                value={@form_keywords}
                placeholder="如：LLM, GPT, transformer"
                class="input input-bordered input-sm w-full max-w-md"
              />
            </div>

            <%!-- 操作 --%>
            <div class="flex gap-2">
              <button type="submit" class="btn btn-sm btn-primary">保存</button>
              <button type="button" phx-click="cancel_edit" class="btn btn-sm btn-ghost">取消</button>
            </div>
          </form>
        </div>
      </div>

      <%!-- Feed 列表 --%>
      <div :if={@feeds != []} class="space-y-3">
        <div
          :for={feed <- @feeds}
          class="card bg-base-200/50 hover:bg-base-200 transition-colors"
        >
          <div class="card-body p-4">
            <div class="flex items-start justify-between">
              <div>
                <h3 class="font-semibold text-sm">{feed.name}</h3>
                <div class="flex flex-wrap gap-1 mt-2">
                  <span
                    :for={tag <- Map.get(feed.rules, "tags", [])}
                    class="badge badge-xs badge-primary"
                  >
                    {tag}
                  </span>
                  <span
                    :for={kw <- Map.get(feed.rules, "keywords", [])}
                    class="badge badge-xs badge-warning"
                  >
                    {kw}
                  </span>
                </div>
              </div>
              <div class="flex items-center gap-1">
                <.link
                  navigate={~p"/?feed=#{feed.id}"}
                  class="btn btn-xs btn-ghost opacity-60 hover:opacity-100"
                  title="查看"
                >
                  <.icon name="hero-eye-mini" class="size-3.5" />
                </.link>
                <button
                  phx-click="edit_feed"
                  phx-value-id={feed.id}
                  class="btn btn-xs btn-ghost opacity-50 hover:opacity-100"
                  title="编辑"
                >
                  <.icon name="hero-pencil-mini" class="size-3.5" />
                </button>
                <button
                  phx-click="delete_feed"
                  phx-value-id={feed.id}
                  class="btn btn-xs btn-ghost text-error opacity-50 hover:opacity-100"
                  title="删除"
                  data-confirm={"确定删除「#{feed.name}」？"}
                >
                  <.icon name="hero-trash-mini" class="size-3.5" />
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div :if={@feeds == []} class="text-center py-8 opacity-40">
        <.icon name="hero-rss" class="size-8 mx-auto mb-2" />
        <p>还没有自定义阅读流</p>
        <p class="text-sm mt-1">点击"创建"按钮开始</p>
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
end
