defmodule Insight.Scraper.Worker do
  @moduledoc """
  HackerNews 爬虫后台调度器。

  启动后，定期（每小时）抓取热门和最新新闻，并将数据保存到数据库中。
  采用三表设计存入快照。
  """
  use GenServer
  require Logger
  alias Insight.News
  alias Insight.Scraper.HN

  # 北京时间 6:00, 12:00, 18:00 对应 UTC 的 22 (前一天), 4, 10
  # 排好序的集合以便 Enum.find 时按自然顺位检查
  @target_utc_hours [4, 10, 22]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("HackerNews 定时爬虫调度器启动...")
    schedule_next_run()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:crawl, state) do
    Logger.info("达到指定时间，开始执行 HN 爬取任务...")

    # 异步执行以免阻塞 GenServer
    Task.start(fn ->
      do_crawl(:news)
      do_crawl(:newest)
      Logger.info("HN 定时抓取任务完成。")
    end)

    schedule_next_run()
    {:noreply, state}
  end

  def run_now do
    send(__MODULE__, :crawl)
  end

  defp schedule_next_run do
    now_utc = DateTime.utc_now()
    current_hour = now_utc.hour

    next_hour = Enum.find(@target_utc_hours, fn h -> h > current_hour end)

    {target_date, target_hour} =
      if next_hour do
        {now_utc, next_hour}
      else
        # 跨天
        {DateTime.add(now_utc, 1, :day), hd(@target_utc_hours)}
      end

    target_time = %{target_date | hour: target_hour, minute: 0, second: 0, microsecond: {0, 0}}
    diff_ms = DateTime.diff(target_time, now_utc, :millisecond)
    delay = max(diff_ms, 1000)

    bjt_hour = rem(target_hour + 8, 24)
    Logger.info("HN 爬虫已调度，将于北京时间 #{bjt_hour}:00 执行 (延迟 #{div(delay, 60_000)} 分钟)")

    Process.send_after(self(), :crawl, delay)
  end

  defp do_crawl(source_type) do
    # 爬取列表
    items = HN.crawl_all(source_type)

    if items != [] do
      # 1. 存入快照主表
      {:ok, snapshot} =
        News.create_crawl_snapshot(%{
          source_type: to_string(source_type),
          crawled_at: DateTime.utc_now(),
          items_count: length(items)
        })

      # 2. 存入新闻条目并关联快照，同时收集新入库的新闻
      saved_items =
        items
        |> Enum.with_index(1)
        |> Enum.map(fn {item, rank} ->
          # Upsert news item（基于 up_id 去重）
          {:ok, news_item} = News.upsert_news_item(Map.drop(item, [:score, :comments_count]))

          # 存入快照关联表（包含当时的排名、分数和评论数）
          News.create_crawl_snapshot_item(%{
            crawl_snapshot_id: snapshot.id,
            news_item_id: news_item.id,
            rank: rank,
            score_at_crawl: item.score,
            comments_count_at_crawl: item.comments_count
          })

          news_item
        end)

      Logger.info("#{source_type} 爬取及入库完成，共 #{length(items)} 条")

      # 3. AI 自动标签和翻译（如果有 API Key）
      if Application.get_env(:insight, :ai_api_key, "") != "" do
        # 自动标签
        untagged = Enum.filter(saved_items, &(is_nil(&1.keywords) or &1.keywords == ""))

        if untagged != [] do
          Logger.info("开始 AI 自动标签，#{length(untagged)} 条待处理...")
          Insight.AI.Tagger.process_news_items(untagged)
        end

        # 自动翻译和摘要
        untranslated = Enum.filter(saved_items, &(is_nil(&1.title_zh) or &1.title_zh == ""))

        if untranslated != [] do
          Logger.info("开始 AI 翻译，#{length(untranslated)} 条待处理...")
          Insight.AI.Summarizer.process_news_items(untranslated)
        end
      end
    end
  end
end
