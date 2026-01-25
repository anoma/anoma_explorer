defmodule AnomaExplorerWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.

  At first glance, this module may seem daunting, but its goal is to provide
  core building blocks for your application, such as tables, forms, and
  inputs. The components consist mostly of markup and are well-documented
  with doc strings and declarative assigns. You may customize and style
  them in any way you want, based on your application growth and needs.

  The foundation for styling is Tailwind CSS, a utility-first CSS framework,
  augmented with daisyUI, a Tailwind CSS plugin that provides UI components
  and themes. Here are useful references:

    * [daisyUI](https://daisyui.com/docs/intro/) - a good place to get
      started and see the available components.

    * [Tailwind CSS](https://tailwindcss.com) - the foundational framework
      we build on. You will use it for layout, sizing, flexbox, grid, and
      spacing.

    * [Heroicons](https://heroicons.com) - see `icon/1` for usage.

    * [Phoenix.Component](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html) -
      the component system used by Phoenix. Some components, such as `<.link>`
      and `<.form>`, are defined there.

  """
  use Phoenix.Component
  use Gettext, backend: AnomaExplorerWeb.Gettext

  alias Phoenix.LiveView.JS

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:info} phx-mounted={show("#flash")}>Welcome Back!</.flash>
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class="toast toast-top toast-end z-50"
      {@rest}
    >
      <div class={[
        "alert w-80 sm:w-96 max-w-80 sm:max-w-96 text-wrap",
        @kind == :info && "alert-info",
        @kind == :error && "alert-error"
      ]}>
        <.icon :if={@kind == :info} name="hero-information-circle" class="size-5 shrink-0" />
        <.icon :if={@kind == :error} name="hero-exclamation-circle" class="size-5 shrink-0" />
        <div>
          <p :if={@title} class="font-semibold">{@title}</p>
          <p>{msg}</p>
        </div>
        <div class="flex-1" />
        <button type="button" class="group self-start cursor-pointer" aria-label={gettext("close")}>
          <.icon name="hero-x-mark" class="size-5 opacity-40 group-hover:opacity-70" />
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Renders a button with navigation support.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" variant="primary">Send!</.button>
      <.button navigate={~p"/"}>Home</.button>
  """
  attr :rest, :global, include: ~w(href navigate patch method download name value disabled)
  attr :class, :any
  attr :variant, :string, values: ~w(primary)
  slot :inner_block, required: true

  def button(%{rest: rest} = assigns) do
    variants = %{"primary" => "btn-primary", nil => "btn-primary btn-soft"}

    assigns =
      assign_new(assigns, :class, fn ->
        ["btn", Map.fetch!(variants, assigns[:variant])]
      end)

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={@class} {@rest}>
        {render_slot(@inner_block)}
      </.link>
      """
    else
      ~H"""
      <button class={@class} {@rest}>
        {render_slot(@inner_block)}
      </button>
      """
    end
  end

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Types

  This function accepts all HTML input types, considering that:

    * You may also set `type="select"` to render a `<select>` tag

    * `type="checkbox"` is used exclusively to render boolean values

    * For live file uploads, see `Phoenix.Component.live_file_input/1`

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input
  for more information. Unsupported types, such as radio, are best
  written directly in your templates.

  ## Examples

  ```heex
  <.input field={@form[:email]} type="email" />
  <.input name="my-input" errors={["oh no!"]} />
  ```

  ## Select type

  When using `type="select"`, you must pass the `options` and optionally
  a `value` to mark which option should be preselected.

  ```heex
  <.input field={@form[:user_type]} type="select" options={["Admin": "admin", "User": "user"]} />
  ```

  For more information on what kind of data can be passed to `options` see
  [`options_for_select`](https://hexdocs.pm/phoenix_html/Phoenix.HTML.Form.html#options_for_select/2).
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               search select tel text textarea time url week hidden)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :class, :any, default: nil, doc: "the input class to use over defaults"
  attr :error_class, :any, default: nil, doc: "the input error class to use over defaults"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "hidden"} = assigns) do
    ~H"""
    <input type="hidden" id={@id} name={@name} value={@value} {@rest} />
    """
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div class="fieldset mb-2">
      <label>
        <input
          type="hidden"
          name={@name}
          value="false"
          disabled={@rest[:disabled]}
          form={@rest[:form]}
        />
        <span class="label">
          <input
            type="checkbox"
            id={@id}
            name={@name}
            value="true"
            checked={@checked}
            class={@class || "checkbox checkbox-sm"}
            {@rest}
          />{@label}
        </span>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div class="fieldset mb-2">
      <label>
        <span :if={@label} class="label mb-1">{@label}</span>
        <select
          id={@id}
          name={@name}
          class={[@class || "w-full select", @errors != [] && (@error_class || "select-error")]}
          multiple={@multiple}
          {@rest}
        >
          <option :if={@prompt} value="">{@prompt}</option>
          {Phoenix.HTML.Form.options_for_select(@options, @value)}
        </select>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div class="fieldset mb-2">
      <label>
        <span :if={@label} class="label mb-1">{@label}</span>
        <textarea
          id={@id}
          name={@name}
          class={[
            @class || "w-full textarea",
            @errors != [] && (@error_class || "textarea-error")
          ]}
          {@rest}
        >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    ~H"""
    <div class="fieldset mb-2">
      <label>
        <span :if={@label} class="label mb-1">{@label}</span>
        <input
          type={@type}
          name={@name}
          id={@id}
          value={Phoenix.HTML.Form.normalize_value(@type, @value)}
          class={[
            @class || "w-full input",
            @errors != [] && (@error_class || "input-error")
          ]}
          {@rest}
        />
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # Helper used by inputs to generate form errors
  defp error(assigns) do
    ~H"""
    <p class="mt-1.5 flex gap-2 items-center text-sm text-error">
      <.icon name="hero-exclamation-circle" class="size-5" />
      {render_slot(@inner_block)}
    </p>
    """
  end

  @doc """
  Renders a header with title.
  """
  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={[@actions != [] && "flex items-center justify-between gap-6", "pb-4"]}>
      <div>
        <h1 class="text-lg font-semibold leading-8">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="text-sm text-base-content/70">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div class="flex-none">{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc """
  Renders a table with generic styling.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="id">{user.id}</:col>
        <:col :let={user} label="username">{user.username}</:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <table class="table table-zebra">
      <thead>
        <tr>
          <th :for={col <- @col}>{col[:label]}</th>
          <th :if={@action != []}>
            <span class="sr-only">{gettext("Actions")}</span>
          </th>
        </tr>
      </thead>
      <tbody id={@id} phx-update={is_struct(@rows, Phoenix.LiveView.LiveStream) && "stream"}>
        <tr :for={row <- @rows} id={@row_id && @row_id.(row)}>
          <td
            :for={col <- @col}
            phx-click={@row_click && @row_click.(row)}
            class={@row_click && "hover:cursor-pointer"}
          >
            {render_slot(col, @row_item.(row))}
          </td>
          <td :if={@action != []} class="w-0 font-semibold">
            <div class="flex gap-4">
              <%= for action <- @action do %>
                {render_slot(action, @row_item.(row))}
              <% end %>
            </div>
          </td>
        </tr>
      </tbody>
    </table>
    """
  end

  @doc """
  Renders a data list.

  ## Examples

      <.list>
        <:item title="Title">{@post.title}</:item>
        <:item title="Views">{@post.views}</:item>
      </.list>
  """
  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <ul class="list">
      <li :for={item <- @item} class="list-row">
        <div class="list-col-grow">
          <div class="font-bold">{item.title}</div>
          <div>{render_slot(item)}</div>
        </div>
      </li>
    </ul>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  You can customize the size and colors of the icons by setting
  width, height, and background color classes.

  Icons are extracted from the `deps/heroicons` directory and bundled within
  your compiled app.css by the plugin in `assets/vendor/heroicons.js`.

  ## Examples

      <.icon name="hero-x-mark" />
      <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :any, default: "size-4"

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  @doc """
  Renders a modal dialog.

  ## Examples

      <.modal id="confirm-modal" show={@show_modal}>
        <:title>Confirm Action</:title>
        Are you sure?
      </.modal>
  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_cancel, JS, default: %JS{}

  slot :title
  slot :inner_block, required: true

  def modal(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={@show && show_modal(@id)}
      phx-remove={hide_modal(@id)}
      data-cancel={JS.exec(@on_cancel, "phx-remove")}
      class="hidden relative z-50"
    >
      <div
        id={"#{@id}-bg"}
        class="fixed inset-0 bg-base-300/80 transition-opacity"
        aria-hidden="true"
      />
      <div class="fixed inset-0 overflow-y-auto" role="dialog" aria-modal="true">
        <div class="flex min-h-full items-center justify-center p-4">
          <div
            id={"#{@id}-container"}
            phx-window-keydown={JS.exec("data-cancel", to: "##{@id}")}
            phx-key="escape"
            phx-click-away={JS.exec("data-cancel", to: "##{@id}")}
            class="relative w-full max-w-lg bg-base-100 rounded-xl shadow-xl p-6 border border-base-300"
          >
            <div class="flex items-center justify-between mb-4">
              <h3 class="text-lg font-semibold text-base-content">{render_slot(@title)}</h3>
              <button
                phx-click={JS.exec("data-cancel", to: "##{@id}")}
                type="button"
                class="btn btn-ghost btn-sm btn-circle"
                aria-label={gettext("close")}
              >
                <.icon name="hero-x-mark" class="w-5 h-5" />
              </button>
            </div>
            {render_slot(@inner_block)}
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp show_modal(id) do
    JS.show(to: "##{id}")
    |> JS.show(to: "##{id}-bg", transition: {"ease-out duration-300", "opacity-0", "opacity-100"})
    |> JS.show(
      to: "##{id}-container",
      transition: {"ease-out duration-300", "opacity-0 scale-95", "opacity-100 scale-100"}
    )
    |> JS.focus_first(to: "##{id}-container")
  end

  defp hide_modal(id) do
    JS.hide(to: "##{id}-bg", transition: {"ease-in duration-200", "opacity-100", "opacity-0"})
    |> JS.hide(
      to: "##{id}-container",
      transition: {"ease-in duration-200", "opacity-100 scale-100", "opacity-0 scale-95"}
    )
    |> JS.hide(to: "##{id}", transition: {"block", "block", "hidden"})
    |> JS.pop_focus()
  end

  @doc """
  Renders a copy button that copies text to clipboard with visual feedback.

  ## Examples

      <.copy_button text={@hash} />
      <.copy_button text={@hash} tooltip="Copy hash" />
      <.copy_button text={@hash} size="sm" />
  """
  attr :text, :string, required: true, doc: "the text to copy to clipboard"
  attr :tooltip, :string, default: "Copy", doc: "the tooltip text"
  attr :size, :string, default: "xs", values: ~w(xs sm), doc: "the button size"
  attr :class, :string, default: nil, doc: "additional CSS classes"

  def copy_button(assigns) do
    ~H"""
    <button
      type="button"
      phx-click={
        JS.dispatch("phx:copy", detail: %{text: @text})
        |> JS.remove_class("opacity-50", to: "#copy-toast")
        |> JS.add_class("opacity-100", to: "#copy-toast")
        |> JS.show(
          to: "#copy-toast",
          transition: {"ease-out duration-200", "opacity-0", "opacity-100"}
        )
        |> JS.hide(
          to: "#copy-toast",
          time: 1500,
          transition: {"ease-in duration-300", "opacity-100", "opacity-0"}
        )
      }
      class={[
        "btn btn-ghost shrink-0 opacity-60 hover:opacity-100",
        @size == "xs" && "btn-xs",
        @size == "sm" && "btn-sm",
        @class
      ]}
      title={@tooltip}
    >
      <.icon
        name="hero-clipboard-document"
        class={[@size == "xs" && "w-3 h-3", @size == "sm" && "w-4 h-4"]}
      />
    </button>
    """
  end

  @doc """
  Renders a toast notification for copy feedback.
  Should be placed once in the layout.

  ## Examples

      <.copy_toast />
  """
  def copy_toast(assigns) do
    ~H"""
    <div
      id="copy-toast"
      class="toast toast-bottom toast-center z-50 hidden opacity-0"
      role="status"
      aria-live="polite"
    >
      <div class="alert alert-success py-2 px-4 min-h-0">
        <.icon name="hero-check-circle" class="w-4 h-4" />
        <span class="text-sm">Copied to clipboard</span>
      </div>
    </div>
    """
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition:
        {"transition-all ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all ease-in duration-200", "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  @doc """
  Renders a clickable network name button that triggers a modal.

  ## Examples

      <.network_button chain_id={tx["chainId"]} />
  """
  attr :chain_id, :integer, required: true

  def network_button(assigns) do
    alias AnomaExplorer.Indexer.Networks

    ~H"""
    <button
      phx-click="show_chain_info"
      phx-value-chain-id={@chain_id}
      class="text-sm cursor-pointer hover:text-primary hover:underline"
      title={"Chain ID: #{@chain_id}"}
    >
      {Networks.short_name(@chain_id)}
    </button>
    """
  end

  @doc """
  Renders a modal with network/chain information.

  ## Examples

      <.chain_info_modal chain={@selected_chain} />
  """
  attr :chain, :map, default: nil

  def chain_info_modal(assigns) do
    ~H"""
    <%= if @chain do %>
      <div class="modal modal-open" phx-click="close_chain_modal">
        <div class="modal-box" phx-click-away="close_chain_modal">
          <button
            class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2"
            phx-click="close_chain_modal"
          >
            <.icon name="hero-x-mark" class="w-5 h-5" />
          </button>

          <div class="space-y-4">
            <div class="flex items-center justify-between">
              <h3 class="text-lg font-semibold">Network Details</h3>
              <div class="flex items-center gap-2">
                <span class="badge badge-info">Mainnet</span>
                <%= if @chain.explorer do %>
                  <a
                    href={@chain.explorer}
                    target="_blank"
                    rel="noopener"
                    class="btn btn-ghost btn-sm"
                  >
                    View Explorer <.icon name="hero-arrow-top-right-on-square" class="w-4 h-4" />
                  </a>
                <% end %>
              </div>
            </div>

            <div class="grid grid-cols-2 gap-4">
              <div>
                <label class="text-xs text-base-content/60 uppercase tracking-wider">Name</label>
                <p class="text-sm">{@chain.short}</p>
              </div>
              <div>
                <label class="text-xs text-base-content/60 uppercase tracking-wider">
                  Display Name
                </label>
                <p class="text-sm">{@chain.name}</p>
              </div>
            </div>

            <div class="grid grid-cols-2 gap-4">
              <div>
                <label class="text-xs text-base-content/60 uppercase tracking-wider">Chain ID</label>
                <p class="text-sm">
                  <span class="badge badge-outline badge-sm">{@chain.chain_id}</span>
                </p>
              </div>
              <div>
                <label class="text-xs text-base-content/60 uppercase tracking-wider">Status</label>
                <p class="text-sm">
                  <span class="badge badge-success badge-sm">Active</span>
                </p>
              </div>
            </div>

            <%= if @chain.explorer do %>
              <div>
                <label class="text-xs text-base-content/60 uppercase tracking-wider">
                  Explorer URL
                </label>
                <p class="text-sm break-all text-base-content/70">{@chain.explorer}</p>
              </div>
            <% end %>
          </div>
        </div>
        <div class="modal-backdrop bg-black/50"></div>
      </div>
    <% end %>
    """
  end

  @doc """
  Renders a loading animation with falling/stacking blocks.

  This provides a visually appealing loading indicator that can be used
  across different views while data is being fetched.

  ## Examples

      <.loading_blocks />
      <.loading_blocks message="Loading transactions..." />
      <.loading_blocks message="Fetching data..." class="py-8" />
  """
  attr :message, :string, default: "Loading...", doc: "the loading message to display"
  attr :class, :string, default: "py-16", doc: "additional CSS classes for the container"

  def loading_blocks(assigns) do
    ~H"""
    <div class={["flex flex-col items-center justify-center", @class]}>
      <div class="loading-blocks mb-4">
        <div class="loading-block"></div>
        <div class="loading-block"></div>
        <div class="loading-block"></div>
        <div class="loading-block"></div>
        <div class="loading-block"></div>
      </div>
      <p class="text-sm text-base-content/60 animate-pulse">{@message}</p>
    </div>
    """
  end

  @doc """
  Renders a table skeleton with falling row animation.

  Use this as a placeholder while table data is loading.

  ## Examples

      <.table_skeleton />
      <.table_skeleton rows={10} />
      <.table_skeleton rows={5} columns={6} />
  """
  attr :rows, :integer, default: 5, doc: "number of skeleton rows to display"
  attr :columns, :integer, default: 8, doc: "number of columns per row"

  def table_skeleton(assigns) do
    ~H"""
    <div class="stat-card">
      <div class="flex items-center justify-between mb-4">
        <div class="h-6 bg-base-300 rounded w-40 animate-pulse"></div>
        <div class="h-8 bg-base-300 rounded w-24 animate-pulse"></div>
      </div>
      <div class="space-y-1">
        <%= for i <- 1..@rows do %>
          <div class="table-skeleton-row" style={"animation-delay: #{i * 0.1}s"}>
            <%= for j <- 1..@columns do %>
              <div class={[
                "skeleton-cell h-4",
                rem(j, 3) == 0 && "w-12",
                rem(j, 3) == 1 && "w-24",
                rem(j, 3) == 2 && "w-16",
                j > 4 && "hidden md:block",
                j > 6 && "hidden lg:block"
              ]}>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # However the error messages in our forms and APIs are generated
    # dynamically, so we need to translate them by calling Gettext
    # with our gettext backend as first argument. Translations are
    # available in the errors.po file (as we use the "errors" domain).
    if count = opts[:count] do
      Gettext.dngettext(AnomaExplorerWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(AnomaExplorerWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end
end
