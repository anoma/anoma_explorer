defmodule AnomaExplorerWeb.SSL do
  @moduledoc """
  SSL configuration helpers for the endpoint.

  This module provides functions used by Plug.SSL's force_ssl configuration.
  Using module functions instead of anonymous functions allows the config
  to be identical at compile-time and runtime, avoiding Phoenix's
  compile_env validation errors.
  """

  @health_check_paths ["/health", "/health/ready", "/healthz"]

  @doc """
  Returns true if the request path should be excluded from HTTPS redirect.

  Health check endpoints are excluded because load balancers and monitoring
  services often make HTTP requests to these paths.

  Handles both Plug.Conn struct and fallback cases defensively.
  """
  @spec exclude_health_checks?(Plug.Conn.t() | any()) :: boolean()
  def exclude_health_checks?(%Plug.Conn{request_path: path}) do
    path in @health_check_paths
  end

  def exclude_health_checks?(_other) do
    # Fallback for unexpected input - don't exclude, allow SSL redirect
    false
  end
end
