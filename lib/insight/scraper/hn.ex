defmodule Insight.Scraper.HN do
  @moduledoc """
  HackerNews HTML 页面抓取与解析模块。

  提供抓取首页和最新页面的功能，支持分页，并解析出标题、URL、分数、评论数等信息。
  """
  require Logger

  @base_url "https://news.ycombinator.com"
  @max_items_per_type 300

  @doc """
  爬取指定类型（:news 热门, :newest 最新）的所有页面。
  """
  def crawl_all(source_type, max_items \\ @max_items_per_type) do
    start_url =
      case source_type do
        :news -> @base_url
        :newest -> "#{@base_url}/newest"
      end

    Logger.info("开始爬取 #{source_type}, 目标数量: #{max_items}")
    fetch_pages(start_url, max_items, 1, [])
  end

  defp fetch_pages(_url, max_items, _page, acc) when length(acc) >= max_items do
    Enum.take(acc, max_items)
  end

  defp fetch_pages(nil, _max_items, _page, acc), do: acc

  defp fetch_pages(url, max_items, page, acc) do
    Logger.debug("正在爬取第 #{page} 页: #{url}")

    case fetch_and_parse_page(url) do
      {:ok, {items, next_url}} ->
        new_acc = acc ++ items

        if length(new_acc) < max_items && next_url do
          # 遵守反爬策略，请求间隔 10 秒
          Process.sleep(10_000)
          fetch_pages(next_url, max_items, page + 1, new_acc)
        else
          Enum.take(new_acc, max_items)
        end

      {:error, reason} ->
        Logger.error("爬取失败 #{url}: #{inspect(reason)}")
        acc
    end
  end

  defp fetch_and_parse_page(url) do
    headers = [
      {"User-Agent",
       "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"}
    ]

    case Req.get(url, headers: headers, receive_timeout: 15_000) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, parse_html(body)}

      {:ok, %Req.Response{status: status}} ->
        {:error, "HTTP Error: #{status}"}

      {:error, exception} ->
        {:error, exception}
    end
  end

  @doc """
  解析 HTML 页面，提取新闻列表和下一页链接。
  """
  def parse_html(html) do
    {:ok, document} = Floki.parse_document(html)

    # HN 的新闻项是由紧邻的三个 <tr> 组成：
    # 1. class="athing" 包含标题和链接
    # 2. 从属于第一个的详情行，包含分数、用户、时间、评论数
    # 3. 空白分隔行

    athings = Floki.find(document, "tr.athing")

    items =
      Enum.reduce(athings, [], fn athing, acc ->
        id = Floki.attribute(athing, "id") |> List.first()

        # title 和 url
        titleline = Floki.find(athing, ".titleline > a") |> List.first()

        if id && titleline do
          title = Floki.text(titleline) |> String.trim()
          url = Floki.attribute(titleline, "href") |> List.first() |> normalize_url()

          # 提取域名 domain (如果有 sitebit)
          domain =
            Floki.find(athing, ".sitebit a")
            |> Floki.text()
            |> String.trim()
            |> case do
              "" -> nil
              d -> String.trim(d, "()")
            end

          # 解析紧跟在 athing 后面的 sibling 行内的 subtext
          # Floki 不能直接像 next_sibling 那样找，所以我们在整个 DOM 里找对应的 score 和 subtext
          score_text = Floki.find(document, "#score_#{id}") |> Floki.text()
          score = parse_number(score_text, 0)

          subtext_tr = find_next_sibling_tr(document, id)

          hn_user = Floki.find(subtext_tr, "a.hnuser") |> Floki.text() |> String.trim()
          hn_user = if hn_user == "", do: nil, else: hn_user

          posted_at_attr =
            Floki.find(subtext_tr, "span.age") |> Floki.attribute("title") |> List.first()

          posted_at = parse_posted_at(posted_at_attr)

          # 评论数："N comments" 或者 "discuss" (0评论)
          comments_text =
            Floki.find(subtext_tr, "a[href^='item?id=#{id}']")
            |> Enum.filter(fn a ->
              String.contains?(Floki.text(a), "comment") ||
                String.contains?(Floki.text(a), "discuss")
            end)
            |> Floki.text()

          comments_count = parse_number(comments_text, 0)

          item = %{
            up_id: String.to_integer(id),
            title: title,
            url: url,
            domain: domain,
            score: score,
            hn_user: hn_user,
            posted_at: posted_at,
            comments_count: comments_count
          }

          [item | acc]
        else
          acc
        end
      end)
      |> Enum.reverse()

    next_url =
      document
      |> Floki.find("a.morelink")
      |> Floki.attribute("href")
      |> List.first()
      |> normalize_url()

    {items, next_url}
  end

  # 在整个 document 中找到对应 athing 的紧邻 subtext tr
  # Floki 缺乏便捷的 next_sibling，所以采用按 id 查找最近的 subline 方法
  defp find_next_sibling_tr(document, id) do
    # HackerNews 的结构是非常固定的：id 为 12345 的 athing 后面跟着一个 tr
    # 这个 tr 内部有一个 td.subtext
    # 我们直接找出所有含有正确 item?id 的 a 标签所在的 td.subtext
    Floki.find(document, "td.subtext")
    |> Enum.find(fn node ->
      Floki.find(node, "a[href^='item?id=#{id}']") != [] || Floki.find(node, "#score_#{id}") != []
    end) || []
  end

  defp normalize_url(nil), do: nil
  defp normalize_url("http" <> _ = url), do: url
  defp normalize_url("/" <> _ = path), do: "#{@base_url}#{path}"
  defp normalize_url(path), do: "#{@base_url}/#{path}"

  defp parse_number(str, default) when is_binary(str) do
    case Regex.run(~r/(\d+)/, str) do
      [_, digits] -> String.to_integer(digits)
      _ -> default
    end
  end

  defp parse_number(_, default), do: default

  defp parse_posted_at(nil), do: nil

  defp parse_posted_at(str) when is_binary(str) do
    str_with_tz = if String.match?(str, ~r/(Z|[+-]\d{2}:\d{2})$/), do: str, else: str <> "Z"

    case DateTime.from_iso8601(str_with_tz) do
      {:ok, datetime, _} ->
        datetime

      _ ->
        parts = String.split(str, " ") |> List.first()

        parts_with_tz =
          if String.match?(parts, ~r/(Z|[+-]\d{2}:\d{2})$/), do: parts, else: parts <> "Z"

        case DateTime.from_iso8601(parts_with_tz) do
          {:ok, datetime, _} -> datetime
          _ -> nil
        end
    end
  end

  defp parse_posted_at(_), do: nil
end
