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

  # 每小时执行一次 (毫秒)
  @interval 60 * 60 * 1000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("HackerNews 爬虫调度器启动...")
    # 启动时延迟 5 秒执行一次，后续每小时执行
    Process.send_after(self(), :crawl, 5_000)
    {:ok, %{}}
  end

  @impl true
  def handle_info(:crawl, state) do
    Logger.info("开始执行定时抓取任务...")

    # 异步执行以免阻塞 GenServer
    Task.start(fn ->
      do_crawl(:news)
      do_crawl(:newest)
      Logger.info("定时抓取任务完成。")
    end)

    Process.send_after(self(), :crawl, @interval)
    {:noreply, state}
  end

  def run_now do
    send(__MODULE__, :crawl)
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

      # 2. 存入新闻条目并关联快照
      items
      |> Enum.with_index(1)
      |> Enum.each(fn {item, rank} ->
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
      end)

      Logger.info("#{source_type} 爬取及入库完成，共 #{length(items)} 条")
    end
  end
end
