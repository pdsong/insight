defmodule Insight.AI.DailySummarizer do
  @moduledoc """
  个人专属新闻简报生成器。
  """
  alias Insight.AI
  require Logger

  @doc """
  基于给定的新闻列表和用户核心兴趣画像，生成 Markdown 格式的专属日报。
  """
  def generate_newsletter(news_items, user_profiles) do
    if news_items == [] do
      {:ok, "今日暂无与您兴趣高度相关的新闻。"}
    else
      tag_names = Enum.map(user_profiles, & &1.tag.name) |> Enum.join("、")

      news_text =
        news_items
        |> Enum.with_index(1)
        |> Enum.map(fn {item, idx} ->
          title = item.title_zh || item.title
          summary = String.slice(item.summary_zh || item.summary || "", 0, 150)
          url = item.url || "https://news.ycombinator.com/item?id=#{item.up_id}"
          "#{idx}. [#{title}](#{url})\\n简介：#{summary}"
        end)
        |> Enum.join("\\n\\n")

      system_prompt = """
      你是 Insight 专属新闻分析师。你的任务是根据用户今天的核心兴趣和相关新闻，撰写一份个人专属的【每日新闻简报】。

      要求：
      1. 使用友好的问候语开头（类似："早安！今天为您精选了关于 [兴趣领域] 的核心资讯..."）。
      2. 总结主要趋势：用一段话概括今天为您推荐的新闻的主线趋势，说明为什么这些新闻值得关注。
      3. 高亮推荐：挑选 1-2 篇最重要的新闻，简练地点评其核心价值或看点。
      4. 排版：使用标准 Markdown 格式排版（支持 H2, H3, 粗体等），但不需要列出所有提供的新闻链接，仅仅总结。如果需要引用链接直接引用提供的信息段落中的 Markdown 链接。
      5. 风格：像是一个资深同行写给好友的内部早报，干练、专业、有观点。
      """

      user_prompt = """
      用户的核心兴趣：#{tag_names}

      今天为您精选的新闻：
      #{news_text}
      """

      opts = [
        temperature: 0.6,
        max_tokens: 1500
      ]

      case AI.chat(
             [%{role: "system", content: system_prompt}, %{role: "user", content: user_prompt}],
             opts
           ) do
        {:ok, content} ->
          {:ok, content}

        {:error, err} ->
          Logger.error("Failed to generate daily newsletter: #{inspect(err)}")
          {:error, err}
      end
    end
  end
end
