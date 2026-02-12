defmodule InsightWeb.PageController do
  use InsightWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
