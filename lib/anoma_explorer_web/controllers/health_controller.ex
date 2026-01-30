defmodule AnomaExplorerWeb.HealthController do
  @moduledoc """
  Health check endpoints for load balancers and container orchestration.

  Provides:
  - `/health` - Basic liveness check (app is running)
  - `/health/ready` - Readiness check (app can serve traffic, DB is connected)
  """
  use AnomaExplorerWeb, :controller

  alias AnomaExplorer.Repo

  @doc """
  Basic liveness check. Returns 200 if the application is running.
  Used by load balancers and orchestrators to verify the process is alive.
  """
  def index(conn, _params) do
    conn
    |> put_status(:ok)
    |> json(%{status: "ok", timestamp: DateTime.utc_now()})
  end

  @doc """
  Readiness check. Returns 200 if the application can serve traffic.
  Verifies database connectivity before reporting ready.
  """
  def ready(conn, _params) do
    case check_database() do
      :ok ->
        conn
        |> put_status(:ok)
        |> json(%{
          status: "ready",
          timestamp: DateTime.utc_now(),
          checks: %{database: "ok"}
        })

      {:error, reason} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{
          status: "not_ready",
          timestamp: DateTime.utc_now(),
          checks: %{database: "error"},
          error: inspect(reason)
        })
    end
  end

  defp check_database do
    Repo.query!("SELECT 1")
    :ok
  rescue
    e -> {:error, e}
  end
end
