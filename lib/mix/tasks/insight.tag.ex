defmodule Mix.Tasks.Insight.Tag do
  @shortdoc "Run AI auto-tagging on untagged news items"
  @moduledoc """
  对尚未打标签的新闻条目执行 AI 自动标签和关键词提取。

  ## 使用方式

      # 处理所有未标注的新闻
      mix insight.tag

      # 指定最大处理数量
      mix insight.tag --limit 10
  """
  use Mix.Task
  require Logger
  import Ecto.Query

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} = OptionParser.parse(args, strict: [limit: :integer])
    limit = Keyword.get(opts, :limit, 50)

    Logger.info("=== 开始 AI 自动标签任务 ===")

    # 查找尚未提取关键词的新闻
    news_items =
      Insight.News.NewsItem
      |> where([n], is_nil(n.keywords) or n.keywords == "")
      |> limit(^limit)
      |> Insight.Repo.all()

    if news_items == [] do
      Logger.info("没有需要标注的新闻。")
    else
      Logger.info("发现 #{length(news_items)} 条待标注新闻，开始处理...")
      Insight.AI.Tagger.process_news_items(news_items)
      Logger.info("=== AI 标签任务完成 ===")
    end
  end
end
