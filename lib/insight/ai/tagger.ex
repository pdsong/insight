defmodule Insight.AI.Tagger do
  @moduledoc """
  AI 自动标签与关键词提取模块。

  利用 Qwen 分析新闻标题和 URL，返回匹配的系统标签和关键词。
  与爬虫流程集成，实现抓取 → 自动打标签 → 入库的完整闭环。
  """
  require Logger
  alias Insight.AI
  alias Insight.News

  @system_tags [
    "科技",
    "AI",
    "开源",
    "编程",
    "前端",
    "后端",
    "数据库",
    "云计算",
    "安全",
    "区块链",
    "创业",
    "融资",
    "商业",
    "产品",
    "科普",
    "人文",
    "教育",
    "设计",
    "游戏",
    "硬件",
    "移动端",
    "DevOps",
    "机器学习",
    "自然语言处理",
    "计算机视觉"
  ]

  @doc """
  对一条新闻进行 AI 标签分析和关键词提取。

  返回 `{:ok, %{tags: [...], keywords: "..."}}` 或 `{:error, reason}`
  """
  def analyze(title, url, domain \\ nil) do
    prompt = build_prompt(title, url, domain)

    case AI.ask_json(prompt, system: system_prompt(), temperature: 0.3, max_tokens: 256) do
      {:ok, %{"tags" => tags, "keywords" => keywords}} when is_list(tags) ->
        # 只保留命中的系统标签
        valid_tags = Enum.filter(tags, &(&1 in @system_tags))
        keywords_str = if is_list(keywords), do: Enum.join(keywords, ","), else: keywords
        {:ok, %{tags: valid_tags, keywords: keywords_str}}

      {:ok, data} ->
        Logger.warning("AI 标签返回格式异常: #{inspect(data)}")
        {:ok, %{tags: [], keywords: ""}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  批量处理新闻列表的标签和关键词。
  为每条新闻调用 AI 分析并更新数据库。
  每次请求间隔 1 秒避免限流。
  """
  def process_news_items(news_items) do
    news_items
    |> Enum.each(fn news_item ->
      # 跳过已经有 keywords 的（避免重复处理）
      if is_nil(news_item.keywords) || news_item.keywords == "" do
        case analyze(news_item.title, news_item.url, news_item.domain) do
          {:ok, %{tags: tags, keywords: keywords}} ->
            # 更新 keywords 字段
            News.update_news_item(news_item, %{keywords: keywords})

            # 关联标签
            associate_tags(news_item, tags)

            Logger.debug("已标注: [#{news_item.up_id}] #{news_item.title} → #{inspect(tags)}")

          {:error, reason} ->
            Logger.error("标注失败 [#{news_item.up_id}]: #{inspect(reason)}")
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
    你是一个专业的新闻分类助手。你的任务是分析 Hacker News 上的新闻标题和 URL，
    从给定的标签列表中选择最匹配的标签（1-3个），并提取 3-5 个关键词。

    你必须严格以 JSON 格式返回结果，不要有任何额外的文字。
    """
  end

  defp build_prompt(title, url, domain) do
    domain_info = if domain, do: "域名: #{domain}\n", else: ""

    """
    分析以下新闻，从标签列表中选择 1-3 个最匹配的标签，并提取 3-5 个关键词。

    标题: #{title}
    URL: #{url || "无"}
    #{domain_info}
    可选标签列表: #{Enum.join(@system_tags, ", ")}

    请严格按以下 JSON 格式返回：
    {"tags": ["标签1", "标签2"], "keywords": ["关键词1", "关键词2", "关键词3"]}
    """
  end

  defp associate_tags(news_item, tag_names) do
    # 查找系统标签并关联
    system_tags = News.list_system_tags()

    Enum.each(tag_names, fn tag_name ->
      case Enum.find(system_tags, &(&1.name == tag_name)) do
        nil -> :skip
        tag -> News.add_tag_to_news(news_item, tag)
      end
    end)
  end
end
