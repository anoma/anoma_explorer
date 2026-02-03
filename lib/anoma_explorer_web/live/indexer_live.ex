defmodule AnomaExplorerWeb.IndexerLive do
  @moduledoc """
  LiveView for displaying the Envio Hyperindex GraphQL endpoint configuration.
  The endpoint is configured via the ENVIO_GRAPHQL_URL environment variable.
  """
  use AnomaExplorerWeb, :live_view

  alias AnomaExplorer.Indexer.Client
  alias AnomaExplorer.Settings

  alias AnomaExplorerWeb.Layouts

  @impl true
  def mount(_params, _session, socket) do
    url = Settings.get_envio_url() || ""
    status = if url != "", do: Client.test_connection(url), else: nil

    {:ok,
     socket
     |> assign(:page_title, "Indexer Settings")
     |> assign(:url, url)
     |> assign(:status, status)
     |> assign(:testing, false)}
  end

  @impl true
  def handle_event("test_connection", _params, socket) do
    url = socket.assigns.url

    if url != "" do
      socket = assign(socket, :testing, true)
      send(self(), :do_test_connection)
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("global_search", %{"query" => query}, socket) do
    query = String.trim(query)

    if query != "" do
      {:noreply, push_navigate(socket, to: "/transactions?search=#{URI.encode_www_form(query)}")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(:do_test_connection, socket) do
    status = Client.test_connection(socket.assigns.url)
    {:noreply, socket |> assign(:status, status) |> assign(:testing, false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_path="/settings/indexer">
      <div class="mb-8">
        <div class="flex items-center gap-3 mb-2">
          <div class="p-2.5 bg-primary/10 rounded-xl">
            <.icon name="hero-server-stack" class="w-6 h-6 text-primary" />
          </div>
          <div>
            <h1 class="text-2xl font-bold text-base-content">Indexer Settings</h1>
          </div>
        </div>
        <p class="text-sm text-base-content/60 ml-[52px]">
          View the configured
          <a
            href="https://envio.dev"
            target="_blank"
            rel="noopener"
            class="link link-primary hover:link-primary/80"
          >
            Envio Hyperindex
          </a>
          GraphQL endpoint for indexed blockchain data
        </p>
      </div>

      <div class="stat-card">
        <h2 class="text-lg font-semibold mb-4">GraphQL Endpoint</h2>

        <div class="space-y-4">
          <div class="form-control">
            <label class="label">
              <span class="label-text font-medium">ENVIO_GRAPHQL_URL</span>
              <span class="label-text-alt badge badge-ghost">Environment Variable</span>
            </label>
            <div class="flex gap-2 items-center">
              <div class="relative flex-1">
                <%= if @url != "" do %>
                  <code class="block w-full font-mono text-sm bg-base-200 px-4 py-3 rounded-lg overflow-x-auto">
                    {@url}
                  </code>
                <% else %>
                  <div class="w-full px-4 py-3 rounded-lg bg-base-200 text-base-content/50 italic">
                    Not configured
                  </div>
                <% end %>
              </div>
              <%= if @url != "" do %>
                <.copy_button text={@url} tooltip="Copy URL" size="sm" />
                <button
                  type="button"
                  phx-click="test_connection"
                  disabled={@testing}
                  class="btn btn-outline btn-sm"
                >
                  <%= if @testing do %>
                    <span class="loading loading-spinner loading-xs"></span>
                  <% else %>
                    <.icon name="hero-signal" class="w-4 h-4" />
                  <% end %>
                  Test
                </button>
              <% end %>
            </div>
          </div>
        </div>

        <%= if @status do %>
          <div class={[
            "alert mt-4",
            if(elem(@status, 0) == :ok, do: "alert-success", else: "alert-error")
          ]}>
            <.icon
              name={if elem(@status, 0) == :ok, do: "hero-check-circle", else: "hero-x-circle"}
              class="h-5 w-5"
            />
            <span>{elem(@status, 1)}</span>
          </div>
        <% end %>
      </div>

      <div class="stat-card mt-6">
        <h3 class="text-sm font-semibold mb-3">Configuration</h3>
        <p class="text-sm text-base-content/70 mb-4">
          The indexer endpoint is configured via environment variable. To change it:
        </p>
        <ol class="text-sm text-base-content/70 space-y-2 list-decimal list-inside">
          <li>
            Set the <code class="bg-base-200 px-1.5 py-0.5 rounded font-mono">ENVIO_GRAPHQL_URL</code>
            environment variable in your deployment platform
          </li>
          <li>Restart the application for changes to take effect</li>
        </ol>

        <div class="mt-4 p-3 bg-base-200 rounded-lg">
          <p class="text-xs font-mono text-base-content/60">
            Example: ENVIO_GRAPHQL_URL=https://indexer.dev.hyperindex.xyz/&lt;hash&gt;/v1/graphql
          </p>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
