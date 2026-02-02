defmodule AnomaExplorer.Indexer.StatsSupervisor do
  @moduledoc """
  Supervisor for the StatsSubscriber WebSocket connection.

  This provides isolation for the WebSocket subscriber - if it fails repeatedly,
  it won't bring down the main application supervisor. Uses relaxed restart
  settings since WebSocket connections can be flaky.
  """
  use Supervisor

  require Logger

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      {AnomaExplorer.Indexer.StatsSubscriber, []}
    ]

    # Very relaxed restart settings for flaky network connections:
    # Allow up to 10 restarts in 60 seconds before giving up
    Supervisor.init(children, strategy: :one_for_one, max_restarts: 10, max_seconds: 60)
  end
end
