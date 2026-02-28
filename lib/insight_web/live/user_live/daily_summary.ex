defmodule InsightWeb.UserLive.DailySummary do
  @moduledoc """
  用户专属日报查看。
  """
  use InsightWeb, :live_view
  alias Insight.News

  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_scope.user.id
    summaries = News.list_daily_summaries(user_id)

    selected_summary = List.first(summaries)

    socket =
      socket
      |> assign(:page_title, "个人日报")
      |> assign(:summaries, summaries)
      |> assign(:selected_summary, selected_summary)

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"date" => date_str}, _uri, socket) do
    user_id = socket.assigns.current_scope.user.id

    case Date.from_iso8601(date_str) do
      {:ok, date} ->
        summary = News.get_daily_summary(user_id, date)
        {:noreply, assign(socket, :selected_summary, summary)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-5xl mx-auto py-8 px-4 flex flex-col md:flex-row gap-8">
      <%!-- 侧边栏：历史记录 --%>
      <div class="w-full md:w-64 shrink-0 border-b md:border-b-0 md:border-r border-base-300 pb-6 md:pb-0 md:pr-4">
        <h2 class="text-xl font-bold mb-4 flex items-center gap-2">
          <.icon name="hero-calendar-days" class="size-5 text-primary" /> 日报历史
        </h2>

        <div class="space-y-2 max-h-48 md:max-h-[calc(100vh-12rem)] overflow-y-auto">
          <div :if={@summaries == []} class="text-sm opacity-50 p-4 bg-base-200/50 rounded-lg">
            暂无简报记录，系统将在明天上午 9:00 为您生成第一份简报。
          </div>

          <.link
            :for={summary <- @summaries}
            patch={~p"/daily-summaries?date=#{Date.to_string(summary.date)}"}
            class={"block p-3 rounded-lg transition-colors border " <> if @selected_summary && @selected_summary.id == summary.id, do: "bg-primary/5 text-primary border-primary/20 font-medium", else: "border-transparent hover:bg-base-200"}
          >
            <div class="flex items-center justify-between">
              <span>{summary.date}</span>
              <span class={"text-xs flex items-center gap-1 " <> status_color(summary.status)}>
                <.icon name={status_icon(summary.status)} class="size-3" />
                {status_label(summary.status)}
              </span>
            </div>
          </.link>
        </div>
      </div>

      <%!-- 主内容区：简报正文 --%>
      <div class="flex-1 min-w-0">
        <div
          :if={@selected_summary}
          class="bg-base-100 p-6 md:p-8 rounded-2xl shadow-sm border border-base-200 min-h-[500px]"
        >
          <div class="flex flex-col md:flex-row md:items-center justify-between mb-8 pb-6 border-b border-base-200 gap-4">
            <div class="flex items-center gap-4">
              <div class="p-3 bg-primary/10 rounded-xl">
                <.icon name="hero-newspaper-solid" class="size-8 text-primary" />
              </div>
              <div>
                <h1 class="text-2xl font-bold">每日专属简报</h1>
                <p class="text-sm opacity-60 mt-1 font-medium tracking-wide">
                  {@selected_summary.date} · 为您量身定制的资讯汇编
                </p>
              </div>
            </div>

            <div class={"badge badge-lg " <> badge_color(@selected_summary.status)}>
              {status_label(@selected_summary.status)}
            </div>
          </div>

          <%= case @selected_summary.status do %>
            <% "completed" -> %>
              <div class="prose prose-sm md:prose-base max-w-none prose-a:text-primary hover:prose-a:text-primary-focus prose-headings:font-bold prose-h2:border-b-2 prose-h2:border-base-200 prose-h2:pb-2">
                {raw(Earmark.as_html!(@selected_summary.content || ""))}
              </div>
            <% "generating" -> %>
              <div class="flex flex-col items-center justify-center py-20 opacity-60">
                <span class="loading loading-spinner loading-lg mb-6 text-primary"></span>
                <p class="text-lg font-medium">简报正在由 AI 生成中</p>
                <p class="text-sm mt-2">请稍等片刻，或稍后刷新页面查看...</p>
              </div>
            <% "failed" -> %>
              <div class="flex flex-col items-center justify-center py-20 text-error/80">
                <.icon name="hero-exclamation-triangle" class="size-16 mb-4" />
                <p class="text-lg font-medium">简报生成失败</p>
                <p class="text-sm mt-2 opacity-80">可能由于网络问题或内容过长，请明天再来看看。</p>
              </div>
            <% "pending" -> %>
              <div class="flex flex-col items-center justify-center py-20 opacity-50">
                <.icon name="hero-clock" class="size-16 mb-4" />
                <p class="text-lg font-medium">正在排队等待生成...</p>
              </div>
          <% end %>
        </div>

        <div
          :if={is_nil(@selected_summary)}
          class="flex flex-col items-center justify-center h-full min-h-[500px] opacity-30 bg-base-200/30 rounded-2xl border border-dashed border-base-300"
        >
          <.icon name="hero-document-text" class="size-20 mb-6" />
          <p class="text-xl font-medium">选择左侧日期查看您的专属简报</p>
        </div>
      </div>
    </div>
    """
  end

  defp status_label("pending"), do: "等待中"
  defp status_label("generating"), do: "生成中"
  defp status_label("completed"), do: "已完成"
  defp status_label("failed"), do: "失败"
  defp status_label(_), do: "未知"

  defp status_color("pending"), do: "text-warning"
  defp status_color("generating"), do: "text-info"
  defp status_color("completed"), do: "text-success"
  defp status_color("failed"), do: "text-error"
  defp status_color(_), do: "opacity-50"

  defp status_icon("pending"), do: "hero-clock-mini"
  defp status_icon("generating"), do: "hero-arrow-path-mini"
  defp status_icon("completed"), do: "hero-check-circle-mini"
  defp status_icon("failed"), do: "hero-x-circle-mini"
  defp status_icon(_), do: "hero-question-mark-circle-mini"

  defp badge_color("completed"), do: "badge-success badge-outline"
  defp badge_color("generating"), do: "badge-info badge-outline"
  defp badge_color("failed"), do: "badge-error badge-outline"
  defp badge_color("pending"), do: "badge-warning badge-outline"
  defp badge_color(_), do: "badge-ghost"
end
