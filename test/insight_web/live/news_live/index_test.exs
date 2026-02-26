defmodule InsightWeb.NewsLive.IndexTest do
  @moduledoc """
  新闻列表 LiveView 测试：页面渲染、筛选、交互按钮。
  """
  use InsightWeb.ConnCase

  import Phoenix.LiveViewTest
  import Insight.NewsFixtures

  describe "未登录用户" do
    test "可以访问首页", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "新闻"
    end

    test "首页显示筛选按钮", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "全部"
      assert html =~ "热门"
      assert html =~ "最新"
    end

    test "首页新闻为空时显示提示", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "暂无新闻"
    end
  end

  describe "有新闻数据时" do
    setup %{conn: conn} do
      news1 = news_item_fixture(%{title: "Elixir is great", title_zh: "Elixir 很棒"})
      news2 = news_item_fixture(%{title: "Rust performance"})

      {:ok, tag} =
        Insight.News.create_tag(%{
          name: "lvtest_#{System.unique_integer([:positive])}",
          type: "system"
        })

      Insight.News.add_tag_to_news(news1, tag)

      %{conn: conn, news1: news1, news2: news2, tag: tag}
    end

    test "显示新闻标题", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "Elixir 很棒"
      assert html =~ "Rust performance"
    end

    test "显示新闻标签", %{conn: conn, tag: tag} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ tag.name
    end

    test "搜索过滤新闻", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      html = view |> element("form") |> render_submit(%{search: "Elixir"})
      assert html =~ "Elixir 很棒"
      refute html =~ "Rust performance"
    end
  end

  describe "已登录用户交互" do
    setup :register_and_log_in_user

    setup %{conn: conn} do
      news = news_item_fixture(%{title: "Test interaction news"})
      %{conn: conn, news: news}
    end

    test "显示 like/dislike 按钮", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "hero-hand-thumb-up"
      assert html =~ "hero-hand-thumb-down"
    end

    test "显示收藏按钮", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "hero-bookmark"
    end

    test "点击 like 切换状态", %{conn: conn, news: news} do
      {:ok, view, _html} = live(conn, ~p"/")

      html =
        view
        |> element(
          ~s|button[phx-click=toggle_reaction][phx-value-news-id="#{news.id}"][phx-value-action=like]|
        )
        |> render_click()

      assert html =~ "btn-success"
    end

    test "点击收藏切换状态", %{conn: conn, news: news} do
      {:ok, view, _html} = live(conn, ~p"/")

      html =
        view
        |> element(~s|button[phx-click=toggle_bookmark][phx-value-news-id="#{news.id}"]|)
        |> render_click()

      assert html =~ "text-warning"
    end

    test "标记已读改变视觉状态", %{conn: conn, news: news} do
      {:ok, view, _html} = live(conn, ~p"/")

      html =
        view
        |> element(~s|button[phx-click=mark_read][phx-value-news-id="#{news.id}"]|)
        |> render_click()

      assert html =~ "opacity-50"
      assert html =~ "hero-eye-slash"
    end

    test "一键全部标记已读", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      html =
        view
        |> element("button[phx-click=mark_all_read]")
        |> render_click()

      assert html =~ "opacity-50"
    end
  end
end
