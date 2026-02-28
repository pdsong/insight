defmodule InsightWeb.TagLive.Index do
  @moduledoc """
  标签管理 LiveView。

  展示系统标签（只读）和用户自定义标签（CRUD），
  仅对已登录用户开放。
  """
  use InsightWeb, :live_view
  alias Insight.News

  @impl true
  def mount(_params, _session, socket) do
    user_id = get_user_id(socket)

    socket =
      socket
      |> assign(:page_title, "标签管理")
      |> assign(:system_tags, News.list_system_tags())
      |> assign(:user_tags, if(user_id, do: News.list_user_tags(user_id), else: []))
      |> assign(:editing_tag, nil)
      |> assign(:new_tag_name, "")

    {:ok, socket}
  end

  @impl true
  def handle_event("create_tag", %{"name" => name}, socket) do
    user_id = get_user_id(socket)
    name = String.trim(name)

    if user_id && name != "" do
      case News.create_tag(%{name: name, type: "user", user_id: user_id}) do
        {:ok, _tag} ->
          socket =
            socket
            |> assign(:user_tags, News.list_user_tags(user_id))
            |> assign(:new_tag_name, "")
            |> put_flash(:info, "标签「#{name}」创建成功")

          {:noreply, socket}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "创建失败，标签名可能重复")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("edit_tag", %{"id" => id}, socket) do
    tag = News.get_tag!(id)
    {:noreply, assign(socket, :editing_tag, tag)}
  end

  @impl true
  def handle_event("cancel_edit", _params, socket) do
    {:noreply, assign(socket, :editing_tag, nil)}
  end

  @impl true
  def handle_event("update_tag", %{"name" => name}, socket) do
    tag = socket.assigns.editing_tag
    name = String.trim(name)

    if tag && tag.type == "user" && name != "" do
      case News.update_tag(tag, %{name: name}) do
        {:ok, _tag} ->
          user_id = get_user_id(socket)

          socket =
            socket
            |> assign(:user_tags, News.list_user_tags(user_id))
            |> assign(:editing_tag, nil)
            |> put_flash(:info, "标签已更新为「#{name}」")

          {:noreply, socket}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "更新失败")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete_tag", %{"id" => id}, socket) do
    tag = News.get_tag!(id)

    if tag.type == "user" do
      case News.delete_tag(tag) do
        {:ok, _} ->
          user_id = get_user_id(socket)

          socket =
            socket
            |> assign(:user_tags, News.list_user_tags(user_id))
            |> put_flash(:info, "标签「#{tag.name}」已删除")

          {:noreply, socket}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "删除失败")}
      end
    else
      {:noreply, put_flash(socket, :error, "系统标签不可删除")}
    end
  end

  # ============================================================
  # 渲染
  # ============================================================

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-5xl mx-auto py-8 px-4 space-y-8">
      <div>
        <h1 class="text-2xl font-bold tracking-tight">标签管理</h1>
        <p class="text-sm opacity-60 mt-1">管理系统标签和你的自定义标签</p>
      </div>

      <%!-- 系统标签（只读） --%>
      <section>
        <h2 class="text-lg font-semibold mb-3 flex items-center gap-2">
          <.icon name="hero-tag" class="size-5 opacity-60" /> 系统标签
          <span class="badge badge-sm badge-ghost">{length(@system_tags)}</span>
        </h2>
        <div class="flex flex-wrap gap-2">
          <span
            :for={tag <- @system_tags}
            class="badge badge-outline"
          >
            {tag.name}
          </span>
        </div>
        <p class="text-xs opacity-40 mt-2">系统标签由 AI 自动标注，不可手动修改。</p>
      </section>

      <div class="divider"></div>

      <%!-- 用户自定义标签 --%>
      <section>
        <h2 class="text-lg font-semibold mb-3 flex items-center gap-2">
          <.icon name="hero-plus-circle" class="size-5 opacity-60" /> 我的标签
          <span class="badge badge-sm badge-ghost">{length(@user_tags)}</span>
        </h2>

        <%!-- 创建新标签 --%>
        <form phx-submit="create_tag" class="flex gap-2 mb-4">
          <input
            type="text"
            name="name"
            value={@new_tag_name}
            placeholder="输入新标签名称..."
            class="input input-bordered input-sm flex-1 max-w-xs"
            required
          />
          <button type="submit" class="btn btn-sm btn-primary">
            <.icon name="hero-plus-mini" class="size-4" /> 创建
          </button>
        </form>

        <%!-- 标签列表 --%>
        <div :if={@user_tags != []} class="space-y-2">
          <div
            :for={tag <- @user_tags}
            class="flex items-center gap-3 p-3 rounded-lg bg-base-200/50 hover:bg-base-200 transition-colors"
          >
            <%= if @editing_tag && @editing_tag.id == tag.id do %>
              <form phx-submit="update_tag" class="flex items-center gap-2 flex-1">
                <input
                  type="text"
                  name="name"
                  value={tag.name}
                  class="input input-bordered input-sm flex-1 max-w-xs"
                  autofocus
                  required
                />
                <button type="submit" class="btn btn-sm btn-success">
                  <.icon name="hero-check-mini" class="size-4" />
                </button>
                <button type="button" phx-click="cancel_edit" class="btn btn-sm btn-ghost">
                  <.icon name="hero-x-mark-mini" class="size-4" />
                </button>
              </form>
            <% else %>
              <span class="badge badge-primary">{tag.name}</span>
              <div class="flex-1"></div>
              <button
                phx-click="edit_tag"
                phx-value-id={tag.id}
                class="btn btn-xs btn-ghost opacity-50 hover:opacity-100"
                title="编辑"
              >
                <.icon name="hero-pencil-mini" class="size-3.5" />
              </button>
              <button
                phx-click="delete_tag"
                phx-value-id={tag.id}
                class="btn btn-xs btn-ghost text-error opacity-50 hover:opacity-100"
                title="删除"
                data-confirm="确定要删除标签「#{tag.name}」吗？"
              >
                <.icon name="hero-trash-mini" class="size-3.5" />
              </button>
            <% end %>
          </div>
        </div>

        <div :if={@user_tags == []} class="text-center py-8 opacity-40">
          <.icon name="hero-tag" class="size-8 mx-auto mb-2" />
          <p>还没有自定义标签</p>
          <p class="text-sm mt-1">创建标签后可手动给新闻分类</p>
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
end
