defmodule Insight.AI.Summarizer do
  @moduledoc """
  AI 中文翻译模块。

  对英文新闻标题进行中文翻译（`title_zh`）。
  与爬虫流程集成，可在入库后批量处理。
  """
  require Logger
  alias Insight.AI
  alias Insight.News

  @doc """
  对一条新闻进行标题翻译。

  返回 `{:ok, %{title_zh: "...", summary_zh: nil}}` 或 `{:error, reason}`
  """
  def translate_and_summarize(title, _url, _domain \\ nil) do
    prompt = build_prompt(title)

    case AI.ask_json(prompt, system: system_prompt(), temperature: 0.3, max_tokens: 256) do
      {:ok, %{"title_zh" => title_zh}} ->
        {:ok, %{title_zh: title_zh, summary_zh: nil}}

      {:ok, data} ->
        Logger.warning("AI 翻译返回格式异常: #{inspect(data)}")
        {:ok, %{title_zh: nil, summary_zh: nil}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  批量处理新闻列表的翻译和摘要。
  对尚未翻译的新闻逐条调用 AI 并更新数据库。
  """
  def process_news_items(news_items) do
    news_items
    |> Enum.each(fn news_item ->
      # 跳过已翻译的
      if is_nil(news_item.title_zh) || news_item.title_zh == "" do
        case translate_and_summarize(news_item.title, news_item.url, news_item.domain) do
          {:ok, %{title_zh: title_zh, summary_zh: summary_zh}} ->
            News.update_news_item(news_item, %{title_zh: title_zh, summary_zh: summary_zh})
            Logger.debug("已翻译: [#{news_item.up_id}] #{title_zh}")

          {:error, reason} ->
            Logger.error("翻译失败 [#{news_item.up_id}]: #{inspect(reason)}")
        end

        # 请求间隔，避免 API 限流
        Process.sleep(1_000)
      end
    end)
  end

  # ============================================================
  # 私有函数
  # ============================================================

  defp system_prompt do
    """
    你是一个专业的科技新闻翻译助手。你的任务是将英文新闻标题翻译为自然流畅的中文。

    翻译要求：
    - 保留技术术语的英文原文（如 LLM、API、WASM 等通用缩写）
    - 翻译要自然，不要逐字翻译
    - 中文标题应简洁有力

    你必须严格以 JSON 格式返回结果，不要有任何额外的文字。
    """
  end

  defp build_prompt(title) do
    """
    请翻译以下英文新闻标题为中文。

    标题: #{title}

    请严格按以下 JSON 格式返回：
    {"title_zh": "中文标题"}
    """
  end
end
