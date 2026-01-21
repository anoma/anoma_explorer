defmodule AnomaExplorer.Repo do
  use Ecto.Repo,
    otp_app: :anoma_explorer,
    adapter: Ecto.Adapters.Postgres
end
