defmodule Insight.AI.Recommender do
  @moduledoc """
  AI 推荐理由生成器。

  基于用户兴趣画像和新闻内容生成简短的、口语化的推荐理由。
  """
  alias Insight.AI
  require Logger

  @doc """
  为用户生成一条私人定制的推荐理由。

  ## 参数
  - `news_item` - 待推荐的新闻
  - `user_profiles` - 该用户匹配到的 Top 兴趣画像（Tag 及其权重）

  ## 返回
  - `{:ok, string}` - 例如："因为你近期点赞了『大语言模型』，这篇关于最新的 AI 发展的文章你可能会感兴趣。"
  """
  def generate_reason(news_item, user_profiles) when is_list(user_profiles) do
    if user_profiles == [] do
      {:error, "No tags to base recommendation on"}
    else
      tag_names = Enum.map(user_profiles, & &1.tag.name) |> Enum.join("、")

      system_prompt = """
      你是 Insight 智能新闻推荐助手。
      你的任务是根据用户的【核心兴趣标签】，针对一篇新闻生成【一句话推荐理由】。

      要求：
      1. 必须简短，不超过 40 个中文字符。
      2. 必须包含至少一个用户的核心兴趣标签。
      3. 语气要像个朋友，口语化、自然。
      4. 格式参考："因为你最近关注了 [标签]..." 或 "这篇关于 [标签] 的文章你可能会喜欢，..."
      5. 只返回推荐理由本身，不要带有任何其他文本。
      """

      user_prompt = """
      【用户的核心兴趣标签】：#{tag_names}
      【新闻标题】：#{news_item.title_zh || news_item.title}
      【片段或简介】：#{String.slice(news_item.summary || "", 0, 100)}

      请直接生成一句话推荐理由：
      """

      opts = [
        temperature: 0.7,
        max_tokens: 100
      ]

      case AI.chat(
             [%{role: "system", content: system_prompt}, %{role: "user", content: user_prompt}],
             opts
           ) do
        {:ok, reason} ->
          {:ok, String.trim(reason)}

        {:error, err} ->
          Logger.error("Failed to generate AI recommendation reason: #{inspect(err)}")
          {:error, err}
      end
    end
  end
end
