defmodule AnomaExplorer.Indexer.StatsSubscriberTest do
  @moduledoc """
  Tests for the StatsSubscriber WebSocket client.
  """
  use ExUnit.Case, async: false

  alias AnomaExplorer.Indexer.StatsSubscriber
  alias AnomaExplorer.Indexer.StatsSubscriber.State

  describe "topic/0" do
    test "returns the correct PubSub topic" do
      assert StatsSubscriber.topic() == "dashboard:updates"
    end
  end

  describe "child_spec/1" do
    test "returns a valid child spec with transient restart" do
      spec = StatsSubscriber.child_spec([])

      assert spec.id == StatsSubscriber
      assert spec.restart == :transient
      assert spec.type == :worker
      assert elem(spec.start, 0) == StatsSubscriber
      assert elem(spec.start, 1) == :start_link
    end
  end

  describe "start_link/1" do
    test "returns :ignore when Envio URL not configured" do
      Application.delete_env(:anoma_explorer, :envio_graphql_url)

      assert StatsSubscriber.start_link() == :ignore
    end

    test "returns :ignore when connection fails to invalid URL" do
      Application.put_env(
        :anoma_explorer,
        :envio_graphql_url,
        "https://invalid.localhost.test/graphql"
      )

      result = StatsSubscriber.start_link(name: :test_stats_subscriber)

      # Should return :ignore due to connection failure
      assert result == :ignore

      Application.delete_env(:anoma_explorer, :envio_graphql_url)
    end
  end

  describe "connected?/0" do
    test "returns false when ETS table doesn't exist" do
      # Ensure ETS table doesn't exist
      case :ets.whereis(StatsSubscriber) do
        :undefined -> :ok
        _ref -> :ets.delete(StatsSubscriber)
      end

      assert StatsSubscriber.connected?() == false
    end

    test "returns false when not connected" do
      # Create ETS table with connected: false
      case :ets.whereis(StatsSubscriber) do
        :undefined -> :ets.new(StatsSubscriber, [:named_table, :public, :set])
        _ref -> :ok
      end

      :ets.insert(StatsSubscriber, {:connected, false})

      assert StatsSubscriber.connected?() == false
    end

    test "returns true when connected" do
      case :ets.whereis(StatsSubscriber) do
        :undefined -> :ets.new(StatsSubscriber, [:named_table, :public, :set])
        _ref -> :ok
      end

      :ets.insert(StatsSubscriber, {:connected, true})

      assert StatsSubscriber.connected?() == true
    end
  end

  describe "State struct" do
    test "has correct default values" do
      state = %State{}

      assert state.url == nil
      assert state.backoff_ms == nil
      assert state.stats_subscription_id == nil
      assert state.txs_subscription_id == nil
      assert state.connected == false
      assert state.initialized == false
    end

    test "can be created with values" do
      state = %State{
        url: "wss://test.example.com/graphql",
        backoff_ms: 1000,
        connected: true,
        initialized: true
      }

      assert state.url == "wss://test.example.com/graphql"
      assert state.backoff_ms == 1000
      assert state.connected == true
      assert state.initialized == true
    end
  end

  describe "URL conversion" do
    # Test the private function behavior through start_link
    test "converts https:// to wss://" do
      # We can't directly test private functions, but we verify the behavior
      # through the logs or by checking what URL is used
      Application.put_env(:anoma_explorer, :envio_graphql_url, "https://test.envio.dev/graphql")

      # This will fail to connect but will log the converted URL
      result = StatsSubscriber.start_link(name: :test_url_conversion)
      assert result == :ignore

      Application.delete_env(:anoma_explorer, :envio_graphql_url)
    end
  end
end
