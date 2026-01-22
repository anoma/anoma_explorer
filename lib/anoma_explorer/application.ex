defmodule AnomaExplorer.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      AnomaExplorerWeb.Telemetry,
      AnomaExplorer.Repo,
      {Phoenix.PubSub, name: AnomaExplorer.PubSub},
      # GraphQL response cache for faster repeated queries
      AnomaExplorer.Indexer.Cache,
      # Settings cache (must be after Repo)
      AnomaExplorer.Settings.Cache,
      # Contract monitoring manager (reacts to settings changes)
      AnomaExplorer.Settings.MonitoringManager,
      # Start to serve requests, typically the last entry
      AnomaExplorerWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: AnomaExplorer.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    AnomaExplorerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
