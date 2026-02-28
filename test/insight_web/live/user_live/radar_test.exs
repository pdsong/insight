defmodule InsightWeb.UserLive.RadarTest do
  use InsightWeb.ConnCase

  import Phoenix.LiveViewTest
  import Insight.AccountsFixtures

  describe "Radar LiveView" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "renders radar page titles and components", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/radar")

      assert html =~ "Insight 分析与雷达"
      assert html =~ "你的阅读量化图谱与上下文记忆库"

      assert html =~ "阅读偏好雷达"
      assert html =~ "阅读成就徽章"
      assert html =~ "上下文记忆重温"
    end

    test "displays achievements badges correctly for new user", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/radar")

      assert html =~ "潜水新手"

      # Numbers should be zero
      assert html =~ ~r/<div class="text-3xl font-bold text-primary">\s*0\s*<\/div>/
      assert html =~ ~r/<div class="text-3xl font-bold text-secondary">\s*0\s*<\/div>/
      assert html =~ ~r/<div class="text-3xl font-bold text-accent">\s*0\s*<\/div>/
    end

    test "displays default placeholder for memory arc if empty", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/radar")

      assert html =~ "你还未留下足够的阅读足迹。多阅读、点赞和收藏，我们会为你构建专属阅读图谱"
    end
  end
end
