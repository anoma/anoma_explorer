defmodule AnomaExplorerWeb.Live.Helpers.RealtimeHelpers do
  @moduledoc """
  Shared helpers for real-time update notifications in list views.

  This module provides functions for LiveViews to:
  - Subscribe to entity-specific update notifications
  - Manage notification state (new_items_available, new_items_count)
  - Determine when to show/hide notifications based on pagination and filters

  ## Usage

  In your LiveView:

      defmodule MyAppWeb.TransactionsLive do
        use MyAppWeb, :live_view

        alias MyAppWeb.Live.Helpers.RealtimeHelpers

        @default_filters %{"tx_hash" => "", ...}

        def mount(_params, _session, socket) do
          socket =
            socket
            |> assign(:filters, @default_filters)
            |> assign(:page, 0)
            |> RealtimeHelpers.init_realtime(:transactions, @default_filters)

          {:ok, socket}
        end

        def handle_info({:new_items_available, :transactions, meta}, socket) do
          RealtimeHelpers.handle_new_items(socket, meta)
        end

        def handle_event("refresh_list", _params, socket) do
          socket =
            socket
            |> RealtimeHelpers.dismiss_notification()
            |> assign(:page, 0)
            |> load_data()

          {:noreply, socket}
        end

        def handle_event("dismiss_notification", _params, socket) do
          {:noreply, RealtimeHelpers.dismiss_notification(socket)}
        end
      end
  """

  import Phoenix.LiveView, only: [connected?: 1]
  import Phoenix.Component, only: [assign: 3]

  alias AnomaExplorer.Indexer.ListUpdateNotifier

  @doc """
  Initialize real-time assigns for a list view.

  Call in mount/3 to set up the socket with notification-related assigns
  and subscribe to the entity's update topic.

  ## Parameters

    * `socket` - The LiveView socket
    * `entity_type` - The entity type atom (e.g., :transactions, :resources)
    * `default_filters` - The default filter map for this view (used to detect active filters)

  ## Returns

  Socket with the following assigns added:
    * `:new_items_available` - Boolean, true when new items notification should show
    * `:new_items_count` - Integer, number of new items (0 if unknown)
    * `:realtime_entity` - The entity type this view is subscribed to
    * `:default_filters` - The default filters for filter comparison
  """
  @spec init_realtime(Phoenix.LiveView.Socket.t(), atom(), map()) :: Phoenix.LiveView.Socket.t()
  def init_realtime(socket, entity_type, default_filters \\ %{}) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(
        AnomaExplorer.PubSub,
        ListUpdateNotifier.topic(entity_type)
      )
    end

    socket
    |> assign(:new_items_available, false)
    |> assign(:new_items_count, 0)
    |> assign(:realtime_entity, entity_type)
    |> assign(:default_filters, default_filters)
  end

  @doc """
  Handle the new items available message.

  Call from handle_info/2 when receiving `{:new_items_available, entity, meta}`.

  This function determines whether to show the notification based on:
  - Current page (only shows on page 0)
  - Active filters (only shows when filters match defaults)

  ## Parameters

    * `socket` - The LiveView socket
    * `meta` - Map containing `:added` key with count of new items

  ## Returns

  `{:noreply, socket}` tuple for use in handle_info/2
  """
  @spec handle_new_items(Phoenix.LiveView.Socket.t(), map()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_new_items(socket, %{added: added}) do
    if should_notify?(socket) do
      # Accumulate count if already showing notification
      current_count = socket.assigns[:new_items_count] || 0
      new_count = current_count + added

      {:noreply,
       socket
       |> assign(:new_items_available, true)
       |> assign(:new_items_count, new_count)}
    else
      {:noreply, socket}
    end
  end

  @doc """
  Dismiss the notification and reset count.

  Call when user clicks refresh or dismiss button.

  ## Parameters

    * `socket` - The LiveView socket

  ## Returns

  Socket with notification assigns cleared
  """
  @spec dismiss_notification(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def dismiss_notification(socket) do
    socket
    |> assign(:new_items_available, false)
    |> assign(:new_items_count, 0)
  end

  @doc """
  Check if a notification should be shown based on current state.

  Returns true only when:
  - User is on page 0 (first page)
  - No active filters (filters match defaults)

  This prevents confusing UX where user sees "new items" notification
  but refreshing shows nothing new (because their filters exclude the new items).

  ## Parameters

    * `socket` - The LiveView socket

  ## Returns

  Boolean indicating whether notification should be shown
  """
  @spec should_notify?(Phoenix.LiveView.Socket.t()) :: boolean()
  def should_notify?(socket) do
    page = Map.get(socket.assigns, :page, 0)
    filters = Map.get(socket.assigns, :filters, %{})
    default_filters = Map.get(socket.assigns, :default_filters, %{})

    page == 0 && filters_are_default?(filters, default_filters)
  end

  # Private: Check if current filters match default filters
  defp filters_are_default?(filters, default_filters) do
    # Normalize both to handle potential type differences
    normalize = fn map ->
      map
      |> Enum.map(fn {k, v} -> {to_string(k), to_string(v)} end)
      |> Map.new()
    end

    normalize.(filters) == normalize.(default_filters)
  end
end
