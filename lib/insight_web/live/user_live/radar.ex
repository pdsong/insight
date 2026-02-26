defmodule InsightWeb.UserLive.Radar do
  @moduledoc """
  技术雷达与成就中心 LiveView
  """
  use InsightWeb, :live_view
  alias Insight.Interactions.Stats

  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_scope.user_id

    distribution = Stats.get_tag_distribution(user_id)
    achievements = Stats.get_user_achievements(user_id)
    memory_item = Stats.get_memory_arc(user_id)

    # 填充空数据以便 SVG 雷达图可以即使在没有数据时渲染完整的多边形
    distribution = pad_distribution(distribution)

    socket =
      socket
      |> assign(:page_title, "个人雷达")
      |> assign(:distribution, distribution)
      |> assign(:achievements, achievements)
      |> assign(:memory_item, memory_item)
      |> assign(:radar_points, calculate_radar_points(distribution))

    {:ok, socket}
  end

  defp pad_distribution(dist) do
    needed = 6 - length(dist)

    if needed > 0 do
      pads = Enum.map(1..needed, fn i -> %{name: "未知领域 #{i}", score: 0} end)
      dist ++ pads
    else
      Enum.take(dist, 6)
    end
  end

  defp calculate_radar_points(distribution) do
    max_score = Enum.map(distribution, & &1.score) |> Enum.max(fn -> 1 end)
    max_score = if max_score == 0, do: 1, else: max_score

    # SVG 中心为 (100, 100)，半径为 80
    center_x = 100
    center_y = 100
    radius = 80

    Enum.with_index(distribution)
    |> Enum.map(fn {item, idx} ->
      angle = (idx * 60 - 90) * (:math.pi() / 180)
      normalized_score = item.score / max_score

      x = center_x + radius * normalized_score * :math.cos(angle)
      y = center_y + radius * normalized_score * :math.sin(angle)

      # 文字坐标
      text_x = center_x + (radius + 15) * :math.cos(angle)
      text_y = center_y + (radius + 15) * :math.sin(angle)

      %{
        name: item.name,
        score: item.score,
        x: x,
        y: y,
        text_x: text_x,
        text_y: text_y
      }
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-5xl mx-auto py-8 px-4 space-y-8">
      <div class="flex items-center gap-3 pb-4 border-b border-base-200">
        <.icon name="hero-command-line" class="size-8 text-primary" />
        <div>
          <h1 class="text-2xl font-bold">Insight 分析与雷达</h1>
          <p class="text-sm opacity-60 mt-1">你的阅读量化图谱与上下文记忆库</p>
        </div>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
        <%!-- 模块 1：阅读偏好分布雷达图 --%>
        <div class="card bg-base-100 shadow-sm border border-base-200">
          <div class="card-body">
            <h2 class="card-title text-lg flex items-center gap-2">
              <.icon name="hero-chart-pie" class="size-5 text-primary" /> 阅读偏好雷达
            </h2>
            <div class="flex justify-center py-4 relative">
              <svg
                viewBox="0 0 200 200"
                class="w-full max-w-[280px] h-auto drop-shadow-sm text-base-content relative z-10"
              >
                <%!-- 绘制六边形雷达网 --%>
                <polygon
                  points="100,20 169.28,60 169.28,140 100,180 30.72,140 30.72,60"
                  fill="none"
                  class="stroke-base-300"
                  stroke-width="1"
                />
                <polygon
                  points="100,40 151.96,70 151.96,130 100,160 48.04,130 48.04,70"
                  fill="none"
                  class="stroke-base-200"
                  stroke-width="1"
                />
                <polygon
                  points="100,60 134.64,80 134.64,120 100,140 65.36,120 65.36,80"
                  fill="none"
                  class="stroke-base-200"
                  stroke-width="1"
                />

                <%!-- 轴线 --%>
                <line x1="100" y1="100" x2="100" y2="20" class="stroke-base-200" stroke-width="1" />
                <line x1="100" y1="100" x2="169.28" y2="60" class="stroke-base-200" stroke-width="1" />
                <line x1="100" y1="100" x2="169.28" y2="140" class="stroke-base-200" stroke-width="1" />
                <line x1="100" y1="100" x2="100" y2="180" class="stroke-base-200" stroke-width="1" />
                <line x1="100" y1="100" x2="30.72" y2="140" class="stroke-base-200" stroke-width="1" />
                <line x1="100" y1="100" x2="30.72" y2="60" class="stroke-base-200" stroke-width="1" />

                <%!-- 真实数据绘制的多边形 --%>
                <polygon
                  points={Enum.map(@radar_points, fn p -> "#{p.x},#{p.y}" end) |> Enum.join(" ")}
                  class="fill-primary/20 stroke-primary"
                  stroke-width="2"
                  stroke-linejoin="round"
                />

                <%!-- 数据点和标签 --%>
                <%= for p <- @radar_points do %>
                  <circle
                    cx={p.x}
                    cy={p.y}
                    r="3"
                    class="fill-primary stroke-base-100"
                    stroke-width="1"
                  />
                  <text
                    x={p.text_x}
                    y={p.text_y}
                    text-anchor="middle"
                    alignment-baseline="middle"
                    class={"text-[8px] font-medium fill-current #{if String.starts_with?(p.name, "未知"), do: "opacity-30", else: "opacity-90"}"}
                  >
                    {String.slice(p.name, 0, 8)}
                  </text>
                <% end %>
              </svg>
            </div>
          </div>
        </div>

        <%!-- 模块 2：成就系统 --%>
        <div class="card bg-base-100 shadow-sm border border-base-200">
          <div class="card-body">
            <h2 class="card-title text-lg flex items-center gap-2">
              <.icon name="hero-trophy" class="size-5 text-warning" /> 阅读成就徽章
            </h2>
            <div class="space-y-6 mt-4">
              <div class="flex flex-wrap gap-2">
                <span
                  :for={title <- @achievements.titles}
                  class="badge badge-lg bg-gradient-to-r from-amber-200 to-yellow-400 text-amber-900 border-0 shadow-sm font-medium px-4 py-3"
                >
                  <.icon name="hero-star-solid" class="size-4 mr-1 opacity-80" /> {title}
                </span>
              </div>

              <div class="grid grid-cols-3 gap-4">
                <div class="bg-base-200/50 rounded-xl p-4 text-center">
                  <div class="text-3xl font-bold text-primary">{@achievements.reads}</div>
                  <div class="text-xs opacity-60 mt-1 uppercase tracking-wider">阅读数</div>
                </div>
                <div class="bg-base-200/50 rounded-xl p-4 text-center">
                  <div class="text-3xl font-bold text-secondary">{@achievements.likes}</div>
                  <div class="text-xs opacity-60 mt-1 uppercase tracking-wider">喜欢数</div>
                </div>
                <div class="bg-base-200/50 rounded-xl p-4 text-center">
                  <div class="text-3xl font-bold text-accent">{@achievements.bookmarks}</div>
                  <div class="text-xs opacity-60 mt-1 uppercase tracking-wider">收藏数</div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <%!-- 模块 3：Story Arc Tracker 记忆上下文 --%>
        <div class="card bg-gradient-to-br from-base-100 to-base-200 shadow-sm border border-base-200 md:col-span-2">
          <div class="card-body">
            <h2 class="card-title text-lg flex items-center gap-2 mb-2">
              <.icon name="hero-sparkles" class="size-5 text-purple-500" /> 上下文记忆重温
            </h2>

            <%= if @memory_item do %>
              <div class="bg-white/50 dark:bg-black/20 p-5 rounded-xl border border-base-300">
                <p class="text-sm font-medium text-purple-600 dark:text-purple-400 mb-3 flex items-center gap-1">
                  <.icon name="hero-light-bulb-mini" class="size-4" /> 还记得这篇文章吗？也许现在是温故知新的好时机。
                </p>
                <a
                  href={
                    @memory_item.url || "https://news.ycombinator.com/item?id=#{@memory_item.up_id}"
                  }
                  target="_blank"
                  class="text-lg font-bold hover:text-primary transition-colors block"
                >
                  {@memory_item.title_zh || @memory_item.title}
                </a>
                <p class="text-sm opacity-70 mt-2 line-clamp-2">
                  {@memory_item.summary_zh || @memory_item.title}
                </p>
                <div class="flex items-center gap-2 mt-4 text-xs opacity-50">
                  <span>抓取于：{Calendar.strftime(@memory_item.inserted_at, "%Y-%m-%d %H:%M")}</span>
                </div>
              </div>
            <% else %>
              <div class="text-center py-8 opacity-50 text-sm">
                你还未留下足够的阅读足迹。多阅读、点赞和收藏，我们会为你构建专属阅读图谱。
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
