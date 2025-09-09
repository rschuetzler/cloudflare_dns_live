defmodule CloudflareDnsWeb.DNSComponents do
  @moduledoc """
  Custom components for the DNS management system.
  """
  use Phoenix.Component

  import CloudflareDnsWeb.CoreComponents, only: [icon: 1, hide: 1, hide: 2, show: 1]
  use Gettext, backend: CloudflareDnsWeb.Gettext
  
  alias Phoenix.LiveView.JS

  @doc """
  Renders DNS-specific flash notices with enhanced styling for different operations.

  Supports create (success), update (success), delete (warning), and error states
  with appropriate colors and icons.

  ## Examples

      <.dns_flash kind={:success} flash={@flash} />
      <.dns_flash kind={:warning} flash={@flash} />
      <.dns_flash kind={:error} flash={@flash} />
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:success, :warning, :error, :info], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def dns_flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "dns-flash-#{assigns.kind}" end)

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
        @kind == :success && "alert-success",
        @kind == :warning && "alert-warning", 
        @kind == :error && "alert-error",
        @kind == :info && "alert-info"
      ]}>
        <.icon :if={@kind == :success} name="hero-check-circle" class="size-5 shrink-0" />
        <.icon :if={@kind == :warning} name="hero-exclamation-triangle" class="size-5 shrink-0" />
        <.icon :if={@kind == :error} name="hero-exclamation-circle" class="size-5 shrink-0" />
        <.icon :if={@kind == :info} name="hero-information-circle" class="size-5 shrink-0" />
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
  DNS-specific flash group that renders all flash message types.

  ## Examples

      <.dns_flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "dns-flash-group", doc: "the optional id of flash container"

  def dns_flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.dns_flash kind={:success} flash={@flash} />
      <.dns_flash kind={:warning} flash={@flash} />
      <.dns_flash kind={:info} flash={@flash} />
      <.dns_flash kind={:error} flash={@flash} />

      <.dns_flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.dns_flash>

      <.dns_flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.dns_flash>
    </div>
    """
  end

end