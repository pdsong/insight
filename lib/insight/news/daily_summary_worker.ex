defmodule Insight.News.DailySummaryWorker do
  @moduledoc """
  定时调度，触发每天的 DailySummary 生成。
  默认设定：每天到了指定时间（如 9:00 北京时间），如果今天还没生成则触发生成。
  """
  use GenServer
  require Logger

  # 每小时检查一次
  @check_interval :timer.hours(1)

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    Logger.info("Starting DailySummaryWorker...")
    # 启动时先检查一次
    Process.send_after(self(), :check, :timer.seconds(10))
    {:ok, state}
  end

  @impl true
  def handle_info(:check, state) do
    # 简单实现：我们转换为北京时间 (UTC+8)
    now_bjt = DateTime.utc_now() |> DateTime.add(8, :hour)

    if now_bjt.hour >= 9 do
      Logger.info("Time is past 9:00 AM BJT, triggering generate_all_summaries...")
      Insight.News.DailySummaryGenerator.generate_all_summaries()
    end

    schedule_next_check()
    {:noreply, state}
  end

  defp schedule_next_check do
    Process.send_after(self(), :check, @check_interval)
  end
end
