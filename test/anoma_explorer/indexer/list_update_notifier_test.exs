defmodule AnomaExplorer.Indexer.ListUpdateNotifierTest do
  @moduledoc """
  Tests for the ListUpdateNotifier module.
  """
  use ExUnit.Case, async: false

  alias AnomaExplorer.Indexer.ListUpdateNotifier

  describe "topic/1" do
    test "returns correct topic for transactions" do
      assert ListUpdateNotifier.topic(:transactions) == "list:transactions"
    end

    test "returns correct topic for resources" do
      assert ListUpdateNotifier.topic(:resources) == "list:resources"
    end

    test "returns correct topic for actions" do
      assert ListUpdateNotifier.topic(:actions) == "list:actions"
    end

    test "returns correct topic for compliances" do
      assert ListUpdateNotifier.topic(:compliances) == "list:compliances"
    end

    test "returns correct topic for logics" do
      assert ListUpdateNotifier.topic(:logics) == "list:logics"
    end

    test "returns correct topic for commitments" do
      assert ListUpdateNotifier.topic(:commitments) == "list:commitments"
    end

    test "returns correct topic for nullifiers" do
      assert ListUpdateNotifier.topic(:nullifiers) == "list:nullifiers"
    end
  end

  describe "entity_types/0" do
    test "returns all supported entity types" do
      types = ListUpdateNotifier.entity_types()

      assert :transactions in types
      assert :resources in types
      assert :actions in types
      assert :compliances in types
      assert :logics in types
      assert :commitments in types
      assert :nullifiers in types
      assert length(types) == 7
    end
  end

  describe "child_spec/1" do
    test "returns a valid child spec" do
      spec = ListUpdateNotifier.child_spec([])

      assert spec.id == ListUpdateNotifier
      assert spec.restart == :permanent
      assert spec.type == :worker
      assert elem(spec.start, 0) == ListUpdateNotifier
      assert elem(spec.start, 1) == :start_link
    end
  end

  describe "start_link/1" do
    test "starts the GenServer" do
      # Use a unique name to avoid conflicts
      name = :"test_list_notifier_#{:erlang.unique_integer([:positive])}"
      {:ok, pid} = ListUpdateNotifier.start_link(name: name)

      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end

  describe "message handling" do
    test "handles stats_updated message without crashing" do
      # Start notifier with unique name
      name = :"test_notifier_#{:erlang.unique_integer([:positive])}"
      {:ok, pid} = ListUpdateNotifier.start_link(name: name)

      # Subscribe to a list topic to receive notifications
      Phoenix.PubSub.subscribe(AnomaExplorer.PubSub, "list:transactions")

      # Send first stats update to establish baseline
      stats1 = %{
        transactions: 10,
        resources: 20,
        actions: 5,
        compliances: 3,
        logics: 2,
        commitment_roots: 1
      }

      send(pid, {:stats_updated, stats1})
      Process.sleep(50)

      # Verify process is still alive
      assert Process.alive?(pid)

      # Send second update with increased counts
      stats2 = %{
        transactions: 15,
        resources: 25,
        actions: 8,
        compliances: 4,
        logics: 3,
        commitment_roots: 2
      }

      send(pid, {:stats_updated, stats2})
      Process.sleep(100)

      # Verify process is still alive after handling updates
      assert Process.alive?(pid)

      GenServer.stop(pid)
    end

    test "handles transactions_updated message without crashing" do
      name = :"test_notifier_tx_#{:erlang.unique_integer([:positive])}"
      {:ok, pid} = ListUpdateNotifier.start_link(name: name)

      # Send transactions_updated - should not crash
      send(pid, {:transactions_updated, [%{"id" => "tx1"}]})
      Process.sleep(50)

      # Verify process is still alive
      assert Process.alive?(pid)

      GenServer.stop(pid)
    end
  end
end
