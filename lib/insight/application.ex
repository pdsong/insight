defmodule Insight.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      InsightWeb.Telemetry,
      Insight.Repo,
      {DNSCluster, query: Application.get_env(:insight, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Insight.PubSub}
    ]

    # 根据配置决定是否开启定时爬网服务
    scraper_child =
      if Application.get_env(:insight, :start_scraper, true) do
        [Insight.Scraper.Worker]
      else
        []
      end

    children =
      children ++
        scraper_child ++
        [
          # Start to serve requests, typically the last entry
          InsightWeb.Endpoint
        ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Insight.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    InsightWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
