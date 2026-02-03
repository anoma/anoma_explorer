defmodule AnomaExplorer.Indexer.ClientTest do
  @moduledoc """
  Tests for the Indexer Client module.
  """
  use ExUnit.Case, async: false

  alias AnomaExplorer.Indexer.Client

  setup do
    # Store original config and clean up
    original = Application.get_env(:anoma_explorer, :envio_graphql_url)

    on_exit(fn ->
      if original do
        Application.put_env(:anoma_explorer, :envio_graphql_url, original)
      else
        Application.delete_env(:anoma_explorer, :envio_graphql_url)
      end
    end)

    :ok
  end

  describe "graphql_url/0" do
    test "returns nil when not configured" do
      Application.delete_env(:anoma_explorer, :envio_graphql_url)
      assert Client.graphql_url() == nil
    end

    test "returns URL when configured" do
      Application.put_env(:anoma_explorer, :envio_graphql_url, "https://test.envio.dev/graphql")
      assert Client.graphql_url() == "https://test.envio.dev/graphql"
    end
  end

  describe "configured?/0" do
    test "returns false when URL not configured" do
      Application.delete_env(:anoma_explorer, :envio_graphql_url)
      assert Client.configured?() == false
    end

    test "returns false when URL is empty string" do
      Application.put_env(:anoma_explorer, :envio_graphql_url, "")
      assert Client.configured?() == false
    end

    test "returns true when URL is configured" do
      Application.put_env(:anoma_explorer, :envio_graphql_url, "https://test.envio.dev/graphql")
      assert Client.configured?() == true
    end
  end

  describe "test_connection/0" do
    test "returns error when not configured" do
      Application.delete_env(:anoma_explorer, :envio_graphql_url)
      assert {:error, "Indexer endpoint not configured"} = Client.test_connection()
    end

    test "returns error when empty string" do
      Application.put_env(:anoma_explorer, :envio_graphql_url, "")
      assert {:error, "Indexer endpoint not configured"} = Client.test_connection()
    end
  end

  describe "test_connection/1" do
    test "returns error for invalid URL" do
      assert {:error, "Invalid URL"} = Client.test_connection(nil)
      assert {:error, "Invalid URL"} = Client.test_connection("")
    end

    test "returns error for unreachable host" do
      result = Client.test_connection("https://unreachable.localhost.test/graphql")
      assert {:error, _} = result
    end

    @tag :integration
    @tag skip: System.get_env("ENVIO_INTEGRATION_TEST") != "true"
    test "returns ok for valid Envio endpoint" do
      # This test requires ENVIO_INTEGRATION_TEST=true and a valid endpoint
      url =
        System.get_env("ENVIO_GRAPHQL_URL") ||
          "https://indexer.dev.hyperindex.xyz/db336df/v1/graphql"

      result = Client.test_connection(url)

      case result do
        {:ok, "Connected successfully"} -> :ok
        {:error, reason} -> flunk("Expected success, got error: #{reason}")
      end
    end
  end

  describe "working?/0" do
    test "returns false when not configured" do
      Application.delete_env(:anoma_explorer, :envio_graphql_url)
      assert Client.working?() == false
    end

    test "returns false for invalid URL" do
      Application.put_env(
        :anoma_explorer,
        :envio_graphql_url,
        "https://invalid.localhost.test/graphql"
      )

      assert Client.working?() == false
    end
  end
end
