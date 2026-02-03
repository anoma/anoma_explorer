defmodule AnomaExplorer.Indexer.GraphQLIntegrationTest do
  @moduledoc """
  Integration tests for the GraphQL client against a real Envio endpoint.

  These tests are skipped by default and can be run with:
    ENVIO_INTEGRATION_TEST=true mix test test/anoma_explorer/indexer/graphql_integration_test.exs

  To test a specific endpoint:
    ENVIO_INTEGRATION_TEST=true ENVIO_GRAPHQL_URL=https://indexer.dev.hyperindex.xyz/db336df/v1/graphql mix test test/anoma_explorer/indexer/graphql_integration_test.exs
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
      {:skip, "Envio GraphQL URL not configured. Set ENVIO_GRAPHQL_URL env var."}
    else
      IO.puts("\n  Testing endpoint: #{url}")
      :ok
    end
  end

  describe "endpoint connectivity" do
    @tag timeout: 30_000
    test "can connect and execute introspection query" do
      query = """
      {
        __schema {
          queryType {
            name
            fields {
              name
            }
          }
        }
      }
      """

      result = GraphQL.execute_raw(query)

      case result do
        {:ok, response} ->
          assert Map.has_key?(response, "data")
          schema = get_in(response, ["data", "__schema"])
          assert schema != nil
          assert schema["queryType"]["name"] == "query_root"

          # Log available fields for debugging
          fields = get_in(schema, ["queryType", "fields"]) || []
          field_names = Enum.map(fields, & &1["name"]) |> Enum.sort()
          IO.puts("  Available query fields: #{Enum.join(field_names, ", ")}")

        {:error, {:connection_error, reason}} ->
          flunk("Connection error: #{inspect(reason)}")

        {:error, reason} ->
          flunk("Unexpected error: #{inspect(reason)}")
      end
    end
  end

  describe "Stats entity" do
    @tag timeout: 30_000
    test "Stats table exists and returns valid statistics" do
      result = GraphQL.get_stats()

      case result do
        {:ok, stats} ->
          assert is_integer(stats.transactions), "transactions should be integer"
          assert is_integer(stats.resources), "resources should be integer"
          assert is_integer(stats.consumed), "consumed should be integer"
          assert is_integer(stats.created), "created should be integer"
          assert is_integer(stats.actions), "actions should be integer"
          assert is_integer(stats.compliances), "compliances should be integer"
          assert is_integer(stats.logics), "logics should be integer"
          assert is_integer(stats.commitment_roots), "commitment_roots should be integer"

          # Log stats for visibility
          IO.puts(
            "  Stats: #{stats.transactions} txs, #{stats.resources} resources, #{stats.actions} actions"
          )

          # Consumed + created should equal total resources
          assert stats.consumed + stats.created == stats.resources,
                 "consumed (#{stats.consumed}) + created (#{stats.created}) should equal resources (#{stats.resources})"

        {:error, {:graphql_error, errors}} ->
          # Check if Stats field doesn't exist
          error_messages = Enum.map_join(errors, ", ", & &1["message"])

          if String.contains?(error_messages, "Stats") do
            flunk("Stats table not found in schema. Error: #{error_messages}")
          else
            flunk("GraphQL error: #{error_messages}")
          end

        {:error, {:connection_error, reason}} ->
          flunk("Connection error: #{inspect(reason)}")

        {:error, reason} ->
          flunk("Unexpected error: #{inspect(reason)}")
      end
    end
  end

  describe "Transaction queries" do
    @tag timeout: 30_000
    test "list_transactions returns valid transaction list" do
      result = GraphQL.list_transactions(limit: 5)

      case result do
        {:ok, transactions} ->
          assert is_list(transactions)
          IO.puts("  Found #{length(transactions)} transactions")

          # Verify transaction structure if we have any
          Enum.each(transactions, fn tx ->
            assert Map.has_key?(tx, "id"), "transaction should have id"
            assert Map.has_key?(tx, "evmTransaction"), "transaction should have evmTransaction"

            evm_tx = tx["evmTransaction"]
            assert Map.has_key?(evm_tx, "txHash"), "evmTransaction should have txHash"
            assert Map.has_key?(evm_tx, "blockNumber"), "evmTransaction should have blockNumber"
            assert Map.has_key?(evm_tx, "chainId"), "evmTransaction should have chainId"
          end)

        {:error, {:graphql_error, errors}} ->
          flunk("GraphQL error: #{inspect(errors)}")

        {:error, {:connection_error, reason}} ->
          flunk("Connection error: #{inspect(reason)}")

        {:error, reason} ->
          flunk("Unexpected error: #{inspect(reason)}")
      end
    end

    @tag timeout: 30_000
    test "pagination works correctly" do
      # Get first page
      case GraphQL.list_transactions(limit: 2, offset: 0) do
        {:ok, page1} when length(page1) >= 2 ->
          # Get second page
          case GraphQL.list_transactions(limit: 2, offset: 2) do
            {:ok, [_ | _] = page2} ->
              # Pages should not overlap
              page1_ids = Enum.map(page1, & &1["id"]) |> MapSet.new()
              page2_ids = Enum.map(page2, & &1["id"]) |> MapSet.new()
              overlap = MapSet.intersection(page1_ids, page2_ids)
              assert MapSet.size(overlap) == 0, "Pages should not overlap"

            {:ok, _} ->
              # Not enough data for second page
              :ok

            {:error, reason} ->
              flunk("Error fetching page 2: #{inspect(reason)}")
          end

        {:ok, _} ->
          # Not enough data for pagination test
          IO.puts("  Skipping pagination test - not enough data")
          :ok

        {:error, reason} ->
          flunk("Error fetching page 1: #{inspect(reason)}")
      end
    end
  end

  describe "Resource queries" do
    @tag timeout: 30_000
    test "list_resources returns valid resource list" do
      result = GraphQL.list_resources(limit: 5)

      case result do
        {:ok, resources} ->
          assert is_list(resources)
          IO.puts("  Found #{length(resources)} resources")

          Enum.each(resources, fn resource ->
            assert Map.has_key?(resource, "id")
            assert Map.has_key?(resource, "tag")
            assert Map.has_key?(resource, "isConsumed")
          end)

        {:error, {:graphql_error, errors}} ->
          flunk("GraphQL error: #{inspect(errors)}")

        {:error, reason} ->
          flunk("Unexpected error: #{inspect(reason)}")
      end
    end
  end

  describe "Action queries" do
    @tag timeout: 30_000
    test "list_actions returns valid action list" do
      result = GraphQL.list_actions(limit: 5)

      case result do
        {:ok, actions} ->
          assert is_list(actions)
          IO.puts("  Found #{length(actions)} actions")

          Enum.each(actions, fn action ->
            assert Map.has_key?(action, "id")
            assert Map.has_key?(action, "actionTreeRoot")
          end)

        {:error, {:graphql_error, errors}} ->
          flunk("GraphQL error: #{inspect(errors)}")

        {:error, reason} ->
          flunk("Unexpected error: #{inspect(reason)}")
      end
    end
  end

  describe "ComplianceUnit queries" do
    @tag timeout: 30_000
    test "list_compliance_units returns valid compliance unit list" do
      result = GraphQL.list_compliance_units(limit: 5)

      case result do
        {:ok, units} ->
          assert is_list(units)
          IO.puts("  Found #{length(units)} compliance units")

          Enum.each(units, fn unit ->
            assert Map.has_key?(unit, "id")
          end)

        {:error, {:graphql_error, errors}} ->
          flunk("GraphQL error: #{inspect(errors)}")

        {:error, reason} ->
          flunk("Unexpected error: #{inspect(reason)}")
      end
    end
  end

  describe "LogicInput queries" do
    @tag timeout: 30_000
    test "list_logic_inputs returns valid logic input list" do
      result = GraphQL.list_logic_inputs(limit: 5)

      case result do
        {:ok, inputs} ->
          assert is_list(inputs)
          IO.puts("  Found #{length(inputs)} logic inputs")

          Enum.each(inputs, fn input ->
            assert Map.has_key?(input, "id")
          end)

        {:error, {:graphql_error, errors}} ->
          flunk("GraphQL error: #{inspect(errors)}")

        {:error, reason} ->
          flunk("Unexpected error: #{inspect(reason)}")
      end
    end
  end

  describe "CommitmentTreeRoot queries" do
    @tag timeout: 30_000
    test "list_commitment_roots returns valid commitment root list" do
      result = GraphQL.list_commitment_roots(limit: 5)

      case result do
        {:ok, roots} ->
          assert is_list(roots)
          IO.puts("  Found #{length(roots)} commitment roots")

          Enum.each(roots, fn root ->
            assert Map.has_key?(root, "id")
            assert Map.has_key?(root, "root")
          end)

        {:error, {:graphql_error, errors}} ->
          flunk("GraphQL error: #{inspect(errors)}")

        {:error, reason} ->
          flunk("Unexpected error: #{inspect(reason)}")
      end
    end
  end

  describe "error handling" do
    @tag timeout: 30_000
    test "handles invalid query gracefully" do
      result = GraphQL.execute_raw("{ invalid_field_that_does_not_exist }")

      case result do
        {:ok, response} ->
          # Should contain errors
          assert Map.has_key?(response, "errors"),
                 "Invalid query should return errors in response"

        {:error, _} ->
          # Any error is acceptable for invalid query
          :ok
      end
    end
  end
end
