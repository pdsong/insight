defmodule Insight.AI do
  @moduledoc """
  AI 调用封装模块。

  基于通义千问（Qwen）的 OpenAI 兼容接口，提供通用的 LLM 调用能力。
  所有 AI 功能（翻译、摘要、标签提取等）都通过此模块进行底层调用。

  配置项（在 config 或 runtime.exs 中设置）：
  - `:ai_base_url`  — API 基础 URL
  - `:ai_api_key`   — API Key
  - `:ai_model`     — 使用的模型名
  """
  require Logger

  @default_base_url "https://dashscope.aliyuncs.com/compatible-mode/v1"
  @default_model "qwen3-max-preview"
  @default_max_tokens 1024
  @default_temperature 0.7
  @max_retries 2

  # ============================================================
  # 公共 API
  # ============================================================

  @doc """
  发送 chat completion 请求。

  ## 参数
  - `messages`: OpenAI 格式的消息列表, 如 `[%{role: "user", content: "你好"}]`
  - `opts`: 可选参数
    - `:model` — 模型名（默认从配置读取）
    - `:max_tokens` — 最大返回 token 数
    - `:temperature` — 温度参数
    - `:response_format` — 响应格式，如 `%{type: "json_object"}`

  ## 返回
  - `{:ok, content}` — 成功时返回助手回复的文本内容
  - `{:error, reason}` — 失败时返回错误原因
  """
  def chat(messages, opts \\ []) do
    model = Keyword.get(opts, :model, get_config(:ai_model, @default_model))
    max_tokens = Keyword.get(opts, :max_tokens, @default_max_tokens)
    temperature = Keyword.get(opts, :temperature, @default_temperature)

    body = %{
      model: model,
      messages: messages,
      max_tokens: max_tokens,
      temperature: temperature
    }

    # 如果指定了 JSON 输出格式
    body =
      case Keyword.get(opts, :response_format) do
        nil -> body
        format -> Map.put(body, :response_format, format)
      end

    do_request(body, 0)
  end

  @doc """
  简单的单轮对话：直接传入 user prompt，返回助手回复。
  """
  def ask(prompt, opts \\ []) do
    system_prompt = Keyword.get(opts, :system, nil)

    messages =
      if system_prompt do
        [%{role: "system", content: system_prompt}, %{role: "user", content: prompt}]
      else
        [%{role: "user", content: prompt}]
      end

    chat(messages, opts)
  end

  @doc """
  请求 JSON 格式的回复。自动设置 response_format 并解析返回的 JSON。
  """
  def ask_json(prompt, opts \\ []) do
    opts = Keyword.put(opts, :response_format, %{type: "json_object"})

    case ask(prompt, opts) do
      {:ok, content} -> parse_json_response(content)
      error -> error
    end
  end

  # ============================================================
  # 私有函数
  # ============================================================

  defp do_request(body, retry_count) do
    url = "#{get_config(:ai_base_url, @default_base_url)}/chat/completions"
    api_key = get_config(:ai_api_key, "")

    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"}
    ]

    Logger.debug("AI 请求: model=#{body.model}, messages=#{length(body.messages)}")

    case Req.post(url,
           json: body,
           headers: headers,
           receive_timeout: 60_000,
           pool_timeout: 15_000
         ) do
      {:ok,
       %Req.Response{
         status: 200,
         body: %{"choices" => [%{"message" => %{"content" => content}} | _]}
       }} ->
        # 有些模型会在回复中包含 <think>...</think> 标签（思考过程），需要去掉
        content = strip_thinking_tags(content)
        Logger.debug("AI 回复成功，长度: #{String.length(content)}")
        {:ok, content}

      {:ok, %Req.Response{status: 200, body: body}} ->
        Logger.error("AI 回复格式异常: #{inspect(body)}")
        {:error, :unexpected_response_format}

      {:ok, %Req.Response{status: 429}} ->
        # 限流，等待后重试
        if retry_count < @max_retries do
          wait = :math.pow(2, retry_count + 1) |> round() |> Kernel.*(1000)
          Logger.warning("AI 限流，等待 #{wait}ms 后重试 (#{retry_count + 1}/#{@max_retries})")
          Process.sleep(wait)
          do_request(body, retry_count + 1)
        else
          {:error, :rate_limited}
        end

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.error("AI 请求失败: HTTP #{status}, body=#{inspect(body)}")
        {:error, {:http_error, status, body}}

      {:error, exception} ->
        if retry_count < @max_retries do
          wait = :math.pow(2, retry_count + 1) |> round() |> Kernel.*(1000)
          Logger.warning("AI 请求异常: #{inspect(exception)}，等待 #{wait}ms 后重试")
          Process.sleep(wait)
          do_request(body, retry_count + 1)
        else
          Logger.error("AI 请求最终失败: #{inspect(exception)}")
          {:error, exception}
        end
    end
  end

  # 去除 Qwen 思考模式中的 <think>...</think> 标签
  defp strip_thinking_tags(content) do
    content
    |> String.replace(~r/<think>[\s\S]*?<\/think>\s*/u, "")
    |> String.trim()
  end

  defp parse_json_response(content) do
    # 有些模型可能在 JSON 外面包一层 markdown 代码块
    cleaned =
      content
      |> String.replace(~r/^```json\s*/m, "")
      |> String.replace(~r/\s*```$/m, "")
      |> String.trim()

    case Jason.decode(cleaned) do
      {:ok, data} -> {:ok, data}
      {:error, _} -> {:error, {:json_parse_error, content}}
    end
  end

  defp get_config(key, default) do
    Application.get_env(:insight, key, default)
  end
end
