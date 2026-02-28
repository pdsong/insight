defmodule InsightWeb.UserLive.DailySummaryTest do
  use InsightWeb.ConnCase

  import Phoenix.LiveViewTest
  import Insight.AccountsFixtures

  alias Insight.News

  defp create_summary(user_id, attrs \\ %{}) do
    date = Map.get(attrs, :date, Date.utc_today())
    status = Map.get(attrs, :status, "completed")
    content = Map.get(attrs, :content, "# Mock AI Summary")

    {:ok, summary} =
      News.upsert_daily_summary(%{
        user_id: user_id,
        date: date,
        status: status,
        content: content
      })

    summary
  end

  describe "DailySummary LiveView" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "renders empty state when no summaries", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/daily-summaries")

      assert html =~ "个人日报"
      assert html =~ "暂无简报记录，系统将在明天上午 9:00 为您生成第一份简报"
      assert html =~ "选择左侧日期查看您的专属简报"
    end

    test "renders list of summaries and shows the latest one by default", %{
      conn: conn,
      user: user
    } do
      today = Date.utc_today()
      yesterday = Date.add(today, -1)

      create_summary(user.id, %{date: yesterday, content: "## Yesterday News"})
      create_summary(user.id, %{date: today, content: "## Today News"})

      {:ok, lv, html} = live(conn, ~p"/daily-summaries")

      # Both dates should appear in the sidebar
      assert html =~ Date.to_string(today)
      assert html =~ Date.to_string(yesterday)

      # The latest (today) should be rendered by default
      assert html =~ "Today News"
      refute html =~ "Yesterday News"

      # Click the yesterday link
      html =
        lv
        |> element("a", Date.to_string(yesterday))
        |> render_click()

      # Should now show yesterday's content
      assert html =~ "Yesterday News"
    end

    test "shows proper UI for generating status", %{conn: conn, user: user} do
      create_summary(user.id, %{status: "generating", content: nil})

      {:ok, _lv, html} = live(conn, ~p"/daily-summaries")

      assert html =~ "简报正在由 AI 生成中"
      assert html =~ "请稍等片刻，或稍后刷新页面查看"
    end

    test "shows proper UI for failed status", %{conn: conn, user: user} do
      create_summary(user.id, %{status: "failed", content: nil})

      {:ok, _lv, html} = live(conn, ~p"/daily-summaries")

      assert html =~ "简报生成失败"
    end
  end
end
