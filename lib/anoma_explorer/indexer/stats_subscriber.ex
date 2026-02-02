defmodule AnomaExplorer.Indexer.StatsSubscriber do
  @moduledoc """
  WebSocket subscriber for real-time Stats and Transaction updates from Envio.

  Uses the graphql-ws protocol to subscribe to changes in the Stats singleton
  and recent transactions. Broadcasts updates via Phoenix PubSub.

  Falls back gracefully when WebSocket is unavailable - the dashboard will
  continue using polling in that case.
  """
  use WebSockex

  require Logger

  alias AnomaExplorer.Settings

  @pubsub AnomaExplorer.PubSub
  @topic "dashboard:updates"

  # Reconnection settings
  @initial_backoff_ms 1_000
  @max_backoff_ms 30_000

  # GraphQL-WS protocol message types (supporting both old and new protocol)
  @gql_connection_init "connection_init"
  @gql_connection_ack "connection_ack"
  @gql_subscribe "subscribe"
  @gql_next "next"
  @gql_data "data"
  @gql_error "error"
  @gql_complete "complete"
  @gql_ping "ping"
  @gql_pong "pong"
  @gql_ka "ka"

  defmodule State do
    @moduledoc false
    defstruct [
      :url,
      :backoff_ms,
      :stats_subscription_id,
      :txs_subscription_id,
      connected: false,
      initialized: false
    ]
  end

  # ============================================
  # Public API
  # ============================================

  @doc """
  Child spec with :transient restart to prevent cascading failures.
  If WebSocket connection is unstable, it won't bring down the entire application.
  """
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      restart: :transient,
      type: :worker
    }
  end

  @doc """
  Returns the PubSub topic for dashboard updates.
  """
  def topic, do: @topic

  @doc """
  Starts the subscriber if Envio is configured.
  Returns {:ok, pid} or :ignore if not configured.
  """
  def start_link(opts \\ []) do
    case get_websocket_url() do
      {:ok, url} ->
        Logger.info("StatsSubscriber: Starting WebSocket connection to #{url}")

        # Create ETS table for connection state tracking
        init_ets()

        state = %State{
          url: url,
          backoff_ms: @initial_backoff_ms
        }

        # Trap exits to catch connection failures from the linked WebSockex process.
        # This allows the supervisor to continue starting other children even when
        # the WebSocket endpoint is unavailable.
        old_trap = Process.flag(:trap_exit, true)

        result =
          WebSockex.start_link(url, __MODULE__, state,
            name: Keyword.get(opts, :name, __MODULE__)
          )

        # Check for immediate exit from the WebSockex process
        receive do
          {:EXIT, _pid, reason} ->
            Process.flag(:trap_exit, old_trap)

            Logger.warning(
              "StatsSubscriber: Connection failed: #{inspect(reason)}. " <>
                "Dashboard will use polling instead."
            )

            :ignore
        after
          0 ->
            # No immediate exit, connection succeeded
            Process.flag(:trap_exit, old_trap)
            result
        end

      :not_configured ->
        Logger.info("StatsSubscriber: Envio URL not configured, skipping WebSocket")
        :ignore
    end
  end

  defp init_ets do
    case :ets.whereis(__MODULE__) do
      :undefined ->
        :ets.new(__MODULE__, [:named_table, :public, :set])
        :ets.insert(__MODULE__, {:connected, false})

      _ref ->
        :ok
    end
  end

  defp set_connected(connected) do
    case :ets.whereis(__MODULE__) do
      :undefined -> :ok
      _ref -> :ets.insert(__MODULE__, {:connected, connected})
    end
  end

  @doc """
  Checks if the subscriber is connected and receiving updates.
  Uses ETS to track connection state since WebSockex doesn't support GenServer.call.
  """
  def connected? do
    case :ets.whereis(__MODULE__) do
      :undefined -> false
      _ref -> :ets.lookup(__MODULE__, :connected) == [{:connected, true}]
    end
  catch
    _, _ -> false
  end

  # ============================================
  # WebSockex Callbacks
  # ============================================

  @impl WebSockex
  def handle_connect(_conn, state) do
    Logger.info("StatsSubscriber: WebSocket connected")

    # Schedule sending connection_init in handle_info (handle_connect cannot return {:reply, ...})
    send(self(), :send_connection_init)
    {:ok, %{state | connected: true, backoff_ms: @initial_backoff_ms}}
  end

  @impl WebSockex
  def handle_disconnect(disconnect_map, state) do
    reason = Map.get(disconnect_map, :reason, :unknown)

    Logger.warning(
      "StatsSubscriber: Disconnected: #{inspect(reason)}, full: #{inspect(disconnect_map)}, reconnecting in #{state.backoff_ms}ms"
    )

    # Update ETS connection state
    set_connected(false)

    # Schedule reconnection with exponential backoff
    Process.send_after(self(), :reconnect, state.backoff_ms)
    new_backoff = min(state.backoff_ms * 2, @max_backoff_ms)

    {:ok, %{state | connected: false, initialized: false, backoff_ms: new_backoff}}
  end

  @impl WebSockex
  def handle_frame({:text, msg}, state) do
    case Jason.decode(msg) do
      {:ok, payload} ->
        handle_message(payload, state)

      {:error, reason} ->
        Logger.warning("StatsSubscriber: Failed to decode message: #{inspect(reason)}")
        {:ok, state}
    end
  end

  def handle_frame(_frame, state) do
    {:ok, state}
  end

  @impl WebSockex
  def handle_info(:reconnect, state) do
    Logger.info("StatsSubscriber: Attempting reconnection...")
    {:close, state}
  end

  def handle_info(:subscribe, state) do
    state = send_subscriptions(state)
    {:ok, state}
  end

  def handle_info(:send_connection_init, state) do
    Logger.info("StatsSubscriber: Sending connection_init")
    init_msg = Jason.encode!(%{type: @gql_connection_init})
    {:reply, {:text, init_msg}, state}
  end

  def handle_info(_msg, state) do
    {:ok, state}
  end

  @impl WebSockex
  def handle_cast({:send, msg}, state) do
    {:reply, {:text, msg}, state}
  end

  def handle_cast(_msg, state) do
    {:ok, state}
  end

  @impl WebSockex
  def terminate(reason, _state) do
    Logger.info("StatsSubscriber: Terminated with reason: #{inspect(reason)}")
    set_connected(false)
    :ok
  end

  # ============================================
  # GraphQL-WS Protocol Handling
  # ============================================

  defp handle_message(%{"type" => @gql_connection_ack}, state) do
    Logger.info("StatsSubscriber: Connection acknowledged, subscribing to updates")
    # Connection established, update ETS and send subscriptions
    set_connected(true)
    Process.send(self(), :subscribe, [])
    {:ok, %{state | initialized: true}}
  end

  # Handle "next" (graphql-transport-ws) - new protocol
  defp handle_message(%{"type" => @gql_next, "id" => id, "payload" => payload}, state) do
    handle_subscription_data(id, payload, state)
    {:ok, state}
  end

  # Handle "data" (graphql-ws) - old protocol (Hasura/Envio uses this)
  defp handle_message(%{"type" => @gql_data, "id" => id, "payload" => payload}, state) do
    handle_subscription_data(id, payload, state)
    {:ok, state}
  end

  defp handle_message(%{"type" => @gql_error, "id" => id, "payload" => payload}, state) do
    Logger.warning("StatsSubscriber: Subscription error for #{id}: #{inspect(payload)}")
    {:ok, state}
  end

  defp handle_message(%{"type" => @gql_complete, "id" => id}, state) do
    Logger.info("StatsSubscriber: Subscription #{id} completed")
    {:ok, state}
  end

  # Handle keepalive messages (graphql-ws old protocol)
  defp handle_message(%{"type" => @gql_ka}, state) do
    # Keepalive, no action needed
    {:ok, state}
  end

  defp handle_message(%{"type" => @gql_ping}, state) do
    pong_msg = Jason.encode!(%{type: @gql_pong})
    {:reply, {:text, pong_msg}, state}
  end

  defp handle_message(%{"type" => @gql_pong}, state) do
    {:ok, state}
  end

  defp handle_message(msg, state) do
    Logger.debug("StatsSubscriber: Unhandled message: #{inspect(msg)}")
    {:ok, state}
  end

  # ============================================
  # Subscription Management
  # ============================================

  defp send_subscriptions(state) do
    stats_id = "stats_sub"
    txs_id = "txs_sub"

    # Subscribe to Stats singleton
    stats_query = """
    subscription {
      Stats(where: {id: {_eq: "global"}}) {
        transactions
        resources
        resourcesConsumed
        resourcesCreated
        actions
        complianceUnits
        logicInputs
        commitmentRoots
        lastUpdatedBlock
        lastUpdatedTimestamp
      }
    }
    """

    # Subscribe to recent transactions
    txs_query = """
    subscription {
      Transaction(limit: 10, order_by: {evmTransaction: {blockNumber: desc}}) {
        id
        tags
        logicRefs
        evmTransaction {
          id
          txHash
          blockNumber
          timestamp
          chainId
          from
        }
      }
    }
    """

    send_subscription(stats_id, stats_query)
    send_subscription(txs_id, txs_query)

    %{state | stats_subscription_id: stats_id, txs_subscription_id: txs_id}
  end

  defp send_subscription(id, query) do
    msg =
      Jason.encode!(%{
        id: id,
        type: @gql_subscribe,
        payload: %{query: query}
      })

    WebSockex.cast(self(), {:send, msg})
  end

  # ============================================
  # Data Broadcasting
  # ============================================

  defp handle_subscription_data(id, %{"data" => data}, state) do
    cond do
      id == state.stats_subscription_id and data["Stats"] ->
        broadcast_stats(data["Stats"])

      id == state.txs_subscription_id and data["Transaction"] ->
        broadcast_transactions(data["Transaction"])

      true ->
        Logger.debug("StatsSubscriber: Unknown subscription data for #{id}")
    end
  end

  defp handle_subscription_data(_id, payload, _state) do
    Logger.warning("StatsSubscriber: Unexpected payload format: #{inspect(payload)}")
  end

  defp broadcast_stats([stats | _]) do
    formatted_stats = %{
      transactions: stats["transactions"] || 0,
      resources: stats["resources"] || 0,
      consumed: stats["resourcesConsumed"] || 0,
      created: stats["resourcesCreated"] || 0,
      actions: stats["actions"] || 0,
      compliances: stats["complianceUnits"] || 0,
      logics: stats["logicInputs"] || 0,
      commitment_roots: stats["commitmentRoots"] || 0,
      last_updated_block: stats["lastUpdatedBlock"] || 0,
      last_updated_timestamp: stats["lastUpdatedTimestamp"] || 0
    }

    Logger.debug("StatsSubscriber: Broadcasting stats update")
    Phoenix.PubSub.broadcast(@pubsub, @topic, {:stats_updated, formatted_stats})
  end

  defp broadcast_stats(_), do: :ok

  defp broadcast_transactions(transactions) when is_list(transactions) do
    Logger.debug("StatsSubscriber: Broadcasting #{length(transactions)} transactions")
    Phoenix.PubSub.broadcast(@pubsub, @topic, {:transactions_updated, transactions})
  end

  defp broadcast_transactions(_), do: :ok

  # ============================================
  # URL Handling
  # ============================================

  defp get_websocket_url do
    case Settings.get_envio_url() do
      nil ->
        :not_configured

      url when is_binary(url) ->
        # Convert https:// to wss:// or http:// to ws://
        ws_url =
          url
          |> String.replace(~r{^https://}, "wss://")
          |> String.replace(~r{^http://}, "ws://")

        {:ok, ws_url}
    end
  end
end
