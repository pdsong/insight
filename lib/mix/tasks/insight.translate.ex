defmodule Mix.Tasks.Insight.Translate do
  @shortdoc "Run AI translation and summarization on untranslated news items"
  @moduledoc """
  对尚未翻译的新闻执行 AI 中文翻译和摘要生成。

  ## 使用方式

      # 处理所有未翻译的新闻
      mix insight.translate

      # 指定最大处理数量
      mix insight.translate --limit 10
  """
  use Mix.Task
  require Logger
  import Ecto.Query

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} = OptionParser.parse(args, strict: [limit: :integer])
    limit = Keyword.get(opts, :limit, 50)

    Logger.info("=== 开始 AI 翻译任务 ===")

    # 查找尚未翻译的新闻
    news_items =
      Insight.News.NewsItem
      |> where([n], is_nil(n.title_zh) or n.title_zh == "")
      |> limit(^limit)
      |> Insight.Repo.all()

    if news_items == [] do
      Logger.info("没有需要翻译的新闻。")
    else
      Logger.info("发现 #{length(news_items)} 条待翻译新闻，开始处理...")
      Insight.AI.Summarizer.process_news_items(news_items)
      Logger.info("=== AI 翻译任务完成 ===")
    end
  end
end
