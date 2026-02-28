defmodule InsightWeb.BookmarkLiveTest do
  use InsightWeb.ConnCase

  import Phoenix.LiveViewTest
  import Insight.AccountsFixtures
  import Insight.NewsFixtures
  alias Insight.Interactions

  defp create_bookmarks(_) do
    user = user_fixture()
    news1 = news_item_fixture(%{title: "Bookmarks Test News 1"})
    news2 = news_item_fixture(%{title: "Bookmarks Test News 2"})

    Interactions.toggle_interaction(user.id, news1.id, "bookmark")
    Interactions.toggle_like_dislike(user.id, news2.id, "like")

    %{user: user, news1: news1, news2: news2}
  end

  describe "Bookmark Live" do
    setup [:create_bookmarks]

    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/bookmarks")
      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert flash["error"] == "You must log in to access this page."
    end

    test "lists bookmarks and likes", %{conn: conn, user: user, news1: news1, news2: news2} do
      {:ok, _view, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/bookmarks")

      assert html =~ "我的足迹"
      assert html =~ news1.title
      assert html =~ news2.title
      assert html =~ "收藏"
      assert html =~ "喜欢"
    end
    
    test "removes item when untoggled", %{conn: conn, user: user, news1: news1} do
      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/bookmarks")

      assert has_element?(view, "a", news1.title)

      # 模拟点击移除记录 (取消收藏)
      view
      |> element("button[phx-click='toggle_bookmark'][phx-value-news-id='#{news1.id}']")
      |> render_click()

      # 刷新视图查询
      refute has_element?(view, "a", news1.title)
    end
  end
end
