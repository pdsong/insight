defmodule InsightWeb.PageControllerTest do
  use InsightWeb.ConnCase

  test "GET / renders news page", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "新闻"
  end
end
