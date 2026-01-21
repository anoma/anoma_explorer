defmodule AnomaExplorerWeb.AnalyticsLive do
  @moduledoc """
  LiveView for displaying analytics dashboard.
  Placeholder for Phase 6 implementation.
  """
  use AnomaExplorerWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Analytics")

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <h1 class="text-3xl font-bold mb-6">Analytics Dashboard</h1>
      <p class="text-gray-500">Coming soon in Phase 6...</p>
    </div>
    """
  end
end
