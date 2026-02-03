defmodule AnomaExplorerWeb.RealtimeComponents do
  @moduledoc """
  Components for real-time update notifications in list views.

  Provides a non-intrusive notification banner that appears when new data
  is available, allowing users to refresh at their convenience without
  disrupting their current view.
  """
  use Phoenix.Component

  import AnomaExplorerWeb.CoreComponents

  @doc """
  Renders a "new items available" notification banner.

  Appears at the bottom of the viewport when new items are detected,
  with options to refresh or dismiss.

  ## Attributes

    * `visible` - Whether the banner is visible (boolean, default: false)
    * `entity_name` - Display name for the entity type (e.g., "transactions", "resources")
    * `count` - Number of new items available (integer, default: 0, shows "New" if 0)
    * `class` - Additional CSS classes (string, optional)

  ## Events

  The banner emits these phx-click events:
    * `"refresh_list"` - When user clicks the Refresh button
    * `"dismiss_notification"` - When user clicks the dismiss (X) button
  """
  attr :visible, :boolean, default: false
  attr :entity_name, :string, required: true
  attr :count, :integer, default: 0
  attr :class, :string, default: ""

  def new_items_banner(assigns) do
    ~H"""
    <div
      :if={@visible}
      class={[
        "fixed bottom-4 left-1/2 -translate-x-1/2 z-50",
        "bg-primary text-primary-content px-4 py-2 rounded-full shadow-lg",
        "flex items-center gap-3 animate-slide-up",
        @class
      ]}
    >
      <%!-- Pulsing indicator --%>
      <span class="relative flex h-2 w-2">
        <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-primary-content opacity-75">
        </span>
        <span class="relative inline-flex rounded-full h-2 w-2 bg-primary-content"></span>
      </span>

      <%!-- Message --%>
      <span class="text-sm font-medium">
        <%= if @count > 0 do %>
          {@count} new {@entity_name}
        <% else %>
          New {@entity_name} available
        <% end %>
      </span>

      <%!-- Refresh button --%>
      <button
        phx-click="refresh_list"
        class="btn btn-xs btn-ghost hover:bg-primary-content/20 gap-1"
      >
        <.icon name="hero-arrow-path" class="w-3 h-3" />
        Refresh
      </button>

      <%!-- Dismiss button --%>
      <button
        phx-click="dismiss_notification"
        class="btn btn-xs btn-circle btn-ghost hover:bg-primary-content/20"
        aria-label="Dismiss notification"
      >
        <.icon name="hero-x-mark" class="w-3 h-3" />
      </button>
    </div>
    """
  end

  @doc """
  Renders a minimal inline notification for new items.

  Alternative to the floating banner, displayed inline within the page.
  Useful for contexts where a floating banner would be inappropriate.

  ## Attributes

    * `visible` - Whether the notification is visible
    * `entity_name` - Display name for the entity type
    * `count` - Number of new items available
    * `class` - Additional CSS classes
  """
  attr :visible, :boolean, default: false
  attr :entity_name, :string, required: true
  attr :count, :integer, default: 0
  attr :class, :string, default: ""

  def new_items_inline(assigns) do
    ~H"""
    <div
      :if={@visible}
      class={[
        "flex items-center justify-center gap-2 py-2 px-4",
        "bg-primary/10 border border-primary/20 rounded-lg",
        "text-sm text-primary",
        @class
      ]}
    >
      <span class="relative flex h-2 w-2">
        <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-primary opacity-75">
        </span>
        <span class="relative inline-flex rounded-full h-2 w-2 bg-primary"></span>
      </span>

      <span>
        <%= if @count > 0 do %>
          {@count} new {@entity_name} available
        <% else %>
          New {@entity_name} available
        <% end %>
      </span>

      <button phx-click="refresh_list" class="link link-primary font-medium">
        Refresh
      </button>
    </div>
    """
  end
end
