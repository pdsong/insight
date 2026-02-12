defmodule Insight.Repo do
  use Ecto.Repo,
    otp_app: :insight,
    adapter: Ecto.Adapters.Postgres
end
