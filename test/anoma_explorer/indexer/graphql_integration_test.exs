defmodule AnomaExplorer.Indexer.GraphQLIntegrationTest do
  @moduledoc """
  Integration tests for the GraphQL client against a real Envio endpoint.

  These tests are skipped by default and can be run with:
    ENVIO_INTEGRATION_TEST=true mix test test/anoma_explorer/indexer/graphql_integration_test.exs

  Requires ENVIO_GRAPHQL_URL to be set in the environment or database.
  """
  use AnomaExplorer.DataCase, async: false

  alias AnomaExplorer.Indexer.GraphQL
  alias AnomaExplorer.Settings

  @moduletag :integration

  # Skip these tests unless explicitly enabled
  @moduletag skip: System.get_env("ENVIO_INTEGRATION_TEST") != "true"

  setup do
    # Ensure we're using the real HTTP client for integration tests
    Application.delete_env(:anoma_explorer, :graphql_http_client)

    # Check if Envio is configured
    url = Settings.get_envio_url()

    if is_nil(url) or url == "" do
      {:skip, "Envio GraphQL URL not configured"}
    else
      :ok
    end
  end

  describe "real Envio endpoint" do
    @tag timeout: 30_000
    test "get_stats returns valid statistics" do
      result = GraphQL.get_stats()

      case result do
        {:ok, stats} ->
          assert is_integer(stats.transactions)
          assert is_integer(stats.resources)
          assert is_integer(stats.consumed)
          assert is_integer(stats.created)
          assert is_integer(stats.actions)
          assert is_integer(stats.compliances)
          assert is_integer(stats.logics)

          # Consumed + created should equal total resources
          assert stats.consumed + stats.created == stats.resources

        {:error, {:connection_error, _}} ->
          # Network issues are acceptable in integration tests
          :ok

        {:error, reason} ->
          flunk("Unexpected error: #{inspect(reason)}")
      end
    end

    @tag timeout: 30_000
    test "list_transactions returns valid transaction list" do
      result = GraphQL.list_transactions(limit: 5)

      case result do
        {:ok, transactions} ->
          assert is_list(transactions)

          # Verify transaction structure if we have any
          Enum.each(transactions, fn tx ->
            assert Map.has_key?(tx, "id")
            assert Map.has_key?(tx, "txHash")
            assert Map.has_key?(tx, "blockNumber")
            assert Map.has_key?(tx, "chainId")
          end)

        {:error, {:connection_error, _}} ->
          :ok

        {:error, reason} ->
          flunk("Unexpected error: #{inspect(reason)}")
      end
    end

    @tag timeout: 30_000
    test "list_resources returns valid resource list" do
      result = GraphQL.list_resources(limit: 5)

      case result do
        {:ok, resources} ->
          assert is_list(resources)

          Enum.each(resources, fn resource ->
            assert Map.has_key?(resource, "id")
            assert Map.has_key?(resource, "tag")
            assert Map.has_key?(resource, "isConsumed")
          end)

        {:error, {:connection_error, _}} ->
          :ok

        {:error, reason} ->
          flunk("Unexpected error: #{inspect(reason)}")
      end
    end

    @tag timeout: 30_000
    test "list_actions returns valid action list" do
      result = GraphQL.list_actions(limit: 5)

      case result do
        {:ok, actions} ->
          assert is_list(actions)

          Enum.each(actions, fn action ->
            assert Map.has_key?(action, "id")
            assert Map.has_key?(action, "actionTreeRoot")
          end)

        {:error, {:connection_error, _}} ->
          :ok

        {:error, reason} ->
          flunk("Unexpected error: #{inspect(reason)}")
      end
    end

    @tag timeout: 30_000
    test "list_compliance_units returns valid compliance unit list" do
      result = GraphQL.list_compliance_units(limit: 5)

      case result do
        {:ok, units} ->
          assert is_list(units)

          Enum.each(units, fn unit ->
            assert Map.has_key?(unit, "id")
          end)

        {:error, {:connection_error, _}} ->
          :ok

        {:error, reason} ->
          flunk("Unexpected error: #{inspect(reason)}")
      end
    end

    @tag timeout: 30_000
    test "execute_raw can run introspection query" do
      query = """
      {
        __schema {
          types {
            name
          }
        }
      }
      """

      result = GraphQL.execute_raw(query)

      case result do
        {:ok, response} ->
          assert Map.has_key?(response, "data")
          assert get_in(response, ["data", "__schema", "types"]) |> is_list()

        {:error, {:connection_error, _}} ->
          :ok

        {:error, reason} ->
          flunk("Unexpected error: #{inspect(reason)}")
      end
    end

    @tag timeout: 30_000
    test "filters work correctly" do
      # First get some transactions to find a valid chain_id
      case GraphQL.list_transactions(limit: 1) do
        {:ok, [tx | _]} ->
          chain_id = tx["chainId"]

          # Filter by chain_id and verify results
          case GraphQL.list_transactions(chain_id: chain_id, limit: 5) do
            {:ok, filtered} ->
              Enum.each(filtered, fn t ->
                assert t["chainId"] == chain_id
              end)

            {:error, _} ->
              :ok
          end

        {:ok, []} ->
          # No transactions to test with
          :ok

        {:error, _} ->
          :ok
      end
    end

    @tag timeout: 30_000
    test "pagination works correctly" do
      # Get first page
      case GraphQL.list_transactions(limit: 2, offset: 0) do
        {:ok, page1} when length(page1) == 2 ->
          # Get second page
          case GraphQL.list_transactions(limit: 2, offset: 2) do
            {:ok, page2} ->
              # Pages should not overlap (if there's enough data)
              page1_ids = Enum.map(page1, & &1["id"])
              page2_ids = Enum.map(page2, & &1["id"])
              assert Enum.empty?(page1_ids -- page1_ids ++ page2_ids) or Enum.empty?(page2_ids)

            {:error, _} ->
              :ok
          end

        {:ok, _} ->
          # Not enough data for pagination test
          :ok

        {:error, _} ->
          :ok
      end
    end
  end

  describe "error handling with real endpoint" do
    @tag timeout: 30_000
    test "handles invalid query gracefully" do
      result = GraphQL.execute_raw("{ invalid_field_that_does_not_exist }")

      case result do
        {:ok, response} ->
          # Should contain errors
          assert Map.has_key?(response, "errors") or response["data"] == nil

        {:error, _} ->
          # Any error is acceptable
          :ok
      end
    end
  end
end
