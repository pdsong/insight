defmodule Mix.Tasks.Insight.Crawl do
  @shortdoc "Manually run the HackerNews scraper"
  @moduledoc """
  手动触发 HackerNews 爬虫抓取新闻并入库。

  此任务会启动应用的所有依赖服务（如数据库），然后调用爬虫抓取
  `news`（热门）和 `newest`（最新）模块的数据。

  ## 使用方式

      mix insight.crawl
  """
  use Mix.Task
  require Logger

  @impl Mix.Task
  def run(_args) do
    # 确保应用及其依赖（含数据库）全部启动
    Mix.Task.run("app.start")

    Logger.info("=== 开始手动执行爬虫任务 ===")

    # 因为我们在脚本中执行，所以直接调用 HN 抓取和入库逻辑
    Logger.info(">> 抓取热门新闻 (News)...")
    do_crawl(:news)

    Logger.info(">> 抓取最新新闻 (Newest)...")
    do_crawl(:newest)

    Logger.info("=== 手动爬虫任务执行完毕 ===")
  end

  defp do_crawl(source_type) do
    alias Insight.News
    alias Insight.Scraper.HN

    items = HN.crawl_all(source_type)

    if items != [] do
      {:ok, snapshot} =
        News.create_crawl_snapshot(%{
          source_type: to_string(source_type),
          crawled_at: DateTime.utc_now(),
          items_count: length(items)
        })

      items
      |> Enum.with_index(1)
      |> Enum.each(fn {item, rank} ->
        {:ok, news_item} = News.upsert_news_item(Map.drop(item, [:score, :comments_count]))

        News.create_crawl_snapshot_item(%{
          crawl_snapshot_id: snapshot.id,
          news_item_id: news_item.id,
          rank: rank,
          score_at_crawl: item.score,
          comments_count_at_crawl: item.comments_count
        })
      end)

      Logger.info("✓ [#{source_type}] 成功抓取并入库 #{length(items)} 条数据。")
    else
      Logger.warning("! [#{source_type}] 未抓取到任何数据。")
    end
  end
end
