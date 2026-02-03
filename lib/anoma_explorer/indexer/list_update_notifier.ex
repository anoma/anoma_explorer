defmodule AnomaExplorer.Indexer.ListUpdateNotifier do
  @moduledoc """
  Listens to StatsSubscriber broadcasts and notifies list views when new items are available.

  This module observes the existing stats updates (which already contain counts for all entity
  types) and broadcasts to entity-specific topics when counts increase. This allows list views
  to show "New items available" notifications without requiring additional GraphQL subscriptions.

  ## Architecture

  ```
  StatsSubscriber → "dashboard:updates" → ListUpdateNotifier → "list:{entity}" → LiveViews
  ```

  The notifier compares current counts with previous counts and only broadcasts when there
  are actual new items. It also implements debouncing to prevent notification spam during
  rapid indexing.
  """

  use GenServer

  require Logger

  alias AnomaExplorer.Indexer.StatsSubscriber

  @pubsub AnomaExplorer.PubSub

  # Minimum time between notifications per entity (5 seconds)
  @debounce_ms 5_000

  # Mapping from stats keys to entity types
  @entity_mapping %{
    transactions: :transactions,
    resources: :resources,
    actions: :actions,
    compliances: :compliances,
    logics: :logics,
    commitment_roots: :commitments,
    # Note: nullifiers not in Stats currently, but included for future support
    nullifiers: :nullifiers
  }

  # ============================================
  # Public API
  # ============================================

  @doc """
  Returns the PubSub topic for a given entity type.

  ## Examples

      iex> ListUpdateNotifier.topic(:transactions)
      "list:transactions"

      iex> ListUpdateNotifier.topic(:resources)
      "list:resources"
  """
  def topic(entity) when is_atom(entity), do: "list:#{entity}"

  @doc """
  Returns all supported entity types.
  """
  def entity_types do
    [:transactions, :resources, :actions, :compliances, :logics, :commitments, :nullifiers]
  end

  @doc """
  Starts the notifier process.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @doc """
  Returns the child spec for supervision.
  """
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      restart: :permanent,
      type: :worker
    }
  end

  # ============================================
  # GenServer Callbacks
  # ============================================

  @impl true
  def init(_opts) do
    # Subscribe to stats updates from StatsSubscriber
    Phoenix.PubSub.subscribe(@pubsub, StatsSubscriber.topic())

    Logger.info("ListUpdateNotifier: Started, listening to #{StatsSubscriber.topic()}")

    state = %{
      # Previous counts per entity for delta detection
      counts: %{},
      # Last notification time per entity for debouncing
      last_notified: %{}
    }

    {:ok, state}
  end

  @impl true
  def handle_info({:stats_updated, stats}, state) do
    # Extract current counts from stats
    current_counts = extract_counts(stats)

    # Find entities with increased counts
    {notifications, new_state} =
      Enum.reduce(current_counts, {[], state}, fn {entity, new_count}, {notifs, acc_state} ->
        old_count = Map.get(acc_state.counts, entity, 0)
        added = new_count - old_count

        if added > 0 and should_notify?(entity, acc_state) do
          {[{entity, added} | notifs], update_last_notified(acc_state, entity)}
        else
          {notifs, acc_state}
        end
      end)

    # Update stored counts
    new_state = %{new_state | counts: current_counts}

    # Broadcast notifications
    Enum.each(notifications, fn {entity, added} ->
      broadcast_new_items(entity, added)
    end)

    {:noreply, new_state}
  end

  # Ignore transaction updates (we only care about stats)
  def handle_info({:transactions_updated, _}, state), do: {:noreply, state}

  # Handle any other messages gracefully
  def handle_info(_msg, state), do: {:noreply, state}

  # ============================================
  # Private Functions
  # ============================================

  defp extract_counts(stats) do
    @entity_mapping
    |> Enum.map(fn {stats_key, entity} ->
      {entity, Map.get(stats, stats_key, 0)}
    end)
    |> Map.new()
  end

  defp should_notify?(entity, state) do
    now = System.monotonic_time(:millisecond)
    last = Map.get(state.last_notified, entity, 0)

    now - last >= @debounce_ms
  end

  defp update_last_notified(state, entity) do
    now = System.monotonic_time(:millisecond)
    %{state | last_notified: Map.put(state.last_notified, entity, now)}
  end

  defp broadcast_new_items(entity, added) do
    topic = topic(entity)

    Logger.debug("ListUpdateNotifier: Broadcasting #{added} new #{entity} to #{topic}")

    Phoenix.PubSub.broadcast(
      @pubsub,
      topic,
      {:new_items_available, entity, %{added: added}}
    )
  end
end
