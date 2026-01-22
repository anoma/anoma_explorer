defmodule AnomaExplorer.Indexer.CacheTest do
  @moduledoc """
  Tests for the Indexer Cache module.
  """
  use ExUnit.Case, async: false

  alias AnomaExplorer.Indexer.Cache

  setup do
    # Ensure cache is started for tests
    case GenServer.whereis(Cache) do
      nil ->
        {:ok, _pid} = Cache.start_link([])

      pid when is_pid(pid) ->
        Cache.clear()
    end

    :ok
  end

  describe "get/1 and put/2" do
    test "returns :miss for non-existent key" do
      assert :miss = Cache.get(:nonexistent_key)
    end

    test "stores and retrieves a value" do
      Cache.put(:test_key, "test_value")
      assert {:ok, "test_value"} = Cache.get(:test_key)
    end

    test "stores values with custom TTL" do
      Cache.put(:short_ttl_key, "value", 50)
      assert {:ok, "value"} = Cache.get(:short_ttl_key)

      # Wait for expiration
      Process.sleep(60)
      assert :miss = Cache.get(:short_ttl_key)
    end

    test "returns :miss for expired entries" do
      Cache.put(:expiring_key, "value", 1)
      Process.sleep(10)
      assert :miss = Cache.get(:expiring_key)
    end

    test "can store complex values" do
      value = %{
        transactions: 100,
        resources: 200,
        actions: 50
      }

      Cache.put(:complex_key, value)
      assert {:ok, ^value} = Cache.get(:complex_key)
    end
  end

  describe "invalidate/1" do
    test "removes a specific key" do
      Cache.put(:to_invalidate, "value")
      assert {:ok, "value"} = Cache.get(:to_invalidate)

      Cache.invalidate(:to_invalidate)
      assert :miss = Cache.get(:to_invalidate)
    end

    test "does not affect other keys" do
      Cache.put(:key1, "value1")
      Cache.put(:key2, "value2")

      Cache.invalidate(:key1)

      assert :miss = Cache.get(:key1)
      assert {:ok, "value2"} = Cache.get(:key2)
    end
  end

  describe "clear/0" do
    test "removes all entries" do
      Cache.put(:key1, "value1")
      Cache.put(:key2, "value2")
      Cache.put(:key3, "value3")

      Cache.clear()

      assert :miss = Cache.get(:key1)
      assert :miss = Cache.get(:key2)
      assert :miss = Cache.get(:key3)
    end
  end

  describe "get_or_compute/3" do
    test "returns cached value if present" do
      Cache.put(:cached_key, "cached_value")

      compute_called = :atomics.new(1, [])
      :atomics.put(compute_called, 1, 0)

      result =
        Cache.get_or_compute(:cached_key, 10_000, fn ->
          :atomics.add(compute_called, 1, 1)
          {:ok, "computed_value"}
        end)

      assert {:ok, "cached_value"} = result
      assert :atomics.get(compute_called, 1) == 0
    end

    test "computes and caches value on miss" do
      result =
        Cache.get_or_compute(:new_key, 10_000, fn ->
          {:ok, "computed_value"}
        end)

      assert {:ok, "computed_value"} = result
      assert {:ok, "computed_value"} = Cache.get(:new_key)
    end

    test "does not cache error results" do
      result =
        Cache.get_or_compute(:error_key, 10_000, fn ->
          {:error, :some_error}
        end)

      assert {:error, :some_error} = result
      assert :miss = Cache.get(:error_key)
    end

    test "respects TTL for computed values" do
      Cache.get_or_compute(:ttl_key, 50, fn ->
        {:ok, "value"}
      end)

      assert {:ok, "value"} = Cache.get(:ttl_key)

      Process.sleep(60)
      assert :miss = Cache.get(:ttl_key)
    end
  end
end
