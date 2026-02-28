defmodule InsightWeb.BookmarkLive.Index do
  use InsightWeb, :live_view
  alias Insight.Interactions

  @impl true
  def mount(_params, _session, socket) do
    socket = assign(socket, page_title: "我的足迹")
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    user_id = socket.assigns.current_scope.user.id
    page = parse_int(params["page"], 1)

    interactions_result = Interactions.list_bookmarks_and_likes(user_id, page: page, per_page: 20)

    {:noreply,
     socket
     |> assign(:page, page)
     |> assign(:interactions_result, interactions_result)}
  end

  @impl true
  def handle_event("goto_page", %{"page" => page}, socket) do
    {:noreply, push_patch(socket, to: ~p"/bookmarks?page=#{parse_int(page, 1)}")}
  end

  @impl true
  def handle_event("toggle_reaction", %{"news-id" => news_id_str, "action" => action}, socket) do
    user_id = socket.assigns.current_scope.user.id
    news_id = String.to_integer(news_id_str)

    Interactions.toggle_like_dislike(user_id, news_id, action)
    Interactions.calculate_all_user_interest_profiles_async(user_id)

    # 重新加载当前页数据以反映变化
    interactions_result =
      Interactions.list_bookmarks_and_likes(user_id, page: socket.assigns.page, per_page: 20)

    {:noreply, assign(socket, :interactions_result, interactions_result)}
  end

  @impl true
  def handle_event("toggle_bookmark", %{"news-id" => news_id_str}, socket) do
    user_id = socket.assigns.current_scope.user.id
    news_id = String.to_integer(news_id_str)

    Interactions.toggle_interaction(user_id, news_id, "bookmark")
    Interactions.calculate_all_user_interest_profiles_async(user_id)

    # 重新加载当前页数据以反映变化
    interactions_result =
      Interactions.list_bookmarks_and_likes(user_id, page: socket.assigns.page, per_page: 20)

    {:noreply, assign(socket, :interactions_result, interactions_result)}
  end

  defp parse_int(nil, default), do: default
  defp parse_int("", default), do: default

  defp parse_int(str, default) when is_binary(str) do
    case Integer.parse(str) do
      {n, _} -> n
      :error -> default
    end
  end
end
