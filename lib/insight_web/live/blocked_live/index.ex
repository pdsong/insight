defmodule InsightWeb.BlockedLive.Index do
  @moduledoc """
  屏蔽规则管理 LiveView。

  用户可按标签、域名、关键词创建屏蔽规则，
  命中规则的新闻会在列表中自动过滤。
  """
  use InsightWeb, :live_view
  alias Insight.Interactions

  @block_types [
    {"keyword", "关键词", "hero-chat-bubble-bottom-center"},
    {"domain", "域名", "hero-globe-alt"},
    {"tag", "标签", "hero-tag"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    user_id = get_user_id(socket)

    socket =
      socket
      |> assign(:page_title, "屏蔽管理")
      |> assign(:block_types, @block_types)
      |> assign(:selected_type, "keyword")
      |> assign(:new_value, "")
      |> assign(:blocked_items, load_blocked_items(user_id))

    {:ok, socket}
  end

  @impl true
  def handle_event("select_type", %{"type" => type}, socket) do
    {:noreply, assign(socket, :selected_type, type)}
  end

  @impl true
  def handle_event("create_block", %{"value" => value}, socket) do
    user_id = get_user_id(socket)
    value = String.trim(value)

    if user_id && value != "" do
      case Interactions.create_blocked_item(%{
             user_id: user_id,
             block_type: socket.assigns.selected_type,
             value: value
           }) do
        {:ok, _} ->
          socket =
            socket
            |> assign(:blocked_items, load_blocked_items(user_id))
            |> assign(:new_value, "")
            |> put_flash(:info, "已屏蔽「#{value}」")

          {:noreply, socket}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "添加失败，可能已存在")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete_block", %{"id" => id}, socket) do
    item = Interactions.get_blocked_item!(id)
    {:ok, _} = Interactions.delete_blocked_item(item)

    user_id = get_user_id(socket)

    socket =
      socket
      |> assign(:blocked_items, load_blocked_items(user_id))
      |> put_flash(:info, "已移除屏蔽「#{item.value}」")

    {:noreply, socket}
  end

  # ============================================================
  # 渲染
  # ============================================================

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-5xl mx-auto py-8 px-4 space-y-8">
      <div>
        <h1 class="text-2xl font-bold tracking-tight">屏蔽管理</h1>
        <p class="text-sm opacity-60 mt-1">添加屏蔽规则后，匹配的新闻将自动从列表中隐藏</p>
      </div>

      <%!-- 类型选择 + 添加 --%>
      <div class="card bg-base-200/50">
        <div class="card-body p-5">
          <h2 class="text-sm font-semibold mb-3">添加屏蔽规则</h2>

          <%!-- 类型切换 --%>
          <div class="flex gap-2 mb-3">
            <button
              :for={{type, label, icon} <- @block_types}
              phx-click="select_type"
              phx-value-type={type}
              class={"btn btn-sm #{if @selected_type == type, do: "btn-primary", else: "btn-ghost"}"}
            >
              <.icon name={icon} class="size-4" />
              {label}
            </button>
          </div>

          <%!-- 输入 --%>
          <form phx-submit="create_block" class="flex gap-2">
            <input
              type="text"
              name="value"
              value={@new_value}
              placeholder={placeholder_for(@selected_type)}
              class="input input-bordered input-sm flex-1 max-w-md"
              required
            />
            <button type="submit" class="btn btn-sm btn-primary">
              <.icon name="hero-plus-mini" class="size-4" /> 添加
            </button>
          </form>
        </div>
      </div>

      <%!-- 已有屏蔽规则列表 --%>
      <section>
        <h2 class="text-lg font-semibold mb-3 flex items-center gap-2">
          已屏蔽 <span class="badge badge-sm badge-ghost">{length(@blocked_items)}</span>
        </h2>

        <div :if={@blocked_items != []} class="space-y-2">
          <div
            :for={item <- @blocked_items}
            class="flex items-center gap-3 p-3 rounded-lg bg-base-200/50 hover:bg-base-200 transition-colors"
          >
            <span class={"badge badge-sm #{badge_class(item.block_type)}"}>
              {type_label(item.block_type)}
            </span>
            <span class="flex-1 text-sm font-medium">{item.value}</span>
            <span class="text-xs opacity-40">
              {Calendar.strftime(item.inserted_at, "%m-%d %H:%M")}
            </span>
            <button
              phx-click="delete_block"
              phx-value-id={item.id}
              class="btn btn-xs btn-ghost text-error opacity-50 hover:opacity-100"
              title="移除"
            >
              <.icon name="hero-x-mark-mini" class="size-3.5" />
            </button>
          </div>
        </div>

        <div :if={@blocked_items == []} class="text-center py-8 opacity-40">
          <.icon name="hero-shield-check" class="size-8 mx-auto mb-2" />
          <p>暂无屏蔽规则</p>
          <p class="text-sm mt-1">添加规则后，匹配的新闻将不再显示</p>
        </div>
      </section>
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

  defp load_blocked_items(nil), do: []
  defp load_blocked_items(user_id), do: Interactions.list_blocked_items(user_id)

  defp placeholder_for("keyword"), do: "输入关键词，如：加密货币"
  defp placeholder_for("domain"), do: "输入域名，如：example.com"
  defp placeholder_for("tag"), do: "输入标签名，如：区块链"

  defp badge_class("keyword"), do: "badge-warning"
  defp badge_class("domain"), do: "badge-info"
  defp badge_class("tag"), do: "badge-error"

  defp type_label("keyword"), do: "关键词"
  defp type_label("domain"), do: "域名"
  defp type_label("tag"), do: "标签"
end
