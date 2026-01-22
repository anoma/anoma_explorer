defmodule AnomaExplorer.Indexer.Client do
  @moduledoc """
  Client for interacting with the Envio Hyperindex GraphQL endpoint.

  Provides helper functions to access the configured Envio endpoint
  and execute GraphQL queries against the indexed blockchain data.
  """

  alias AnomaExplorer.Settings

  @doc """
  Returns the configured Envio GraphQL URL, or nil if not set.
  Checks database first, then falls back to environment variable.
  """
  @spec graphql_url() :: String.t() | nil
  def graphql_url do
    Settings.get_envio_url()
  end

  @doc """
  Returns true if the Envio GraphQL endpoint is configured.
  """
  @spec configured?() :: boolean()
  def configured? do
    case graphql_url() do
      nil -> false
      "" -> false
      _url -> true
    end
  end
end
