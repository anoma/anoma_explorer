defmodule AnomaExplorer.Indexer.Client do
  @moduledoc """
  Client for interacting with the Envio Hyperindex GraphQL endpoint.

  Provides helper functions to access the configured Envio endpoint
  and execute GraphQL queries against the indexed blockchain data.
  """

  @doc """
  Returns the configured Envio GraphQL URL, or nil if not set.
  """
  @spec graphql_url() :: String.t() | nil
  def graphql_url do
    Application.get_env(:anoma_explorer, :envio_graphql_url)
  end

  @doc """
  Returns true if the Envio GraphQL endpoint is configured.
  """
  @spec configured?() :: boolean()
  def configured? do
    graphql_url() != nil
  end
end
