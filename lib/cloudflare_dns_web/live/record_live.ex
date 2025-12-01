defmodule CloudflareDnsWeb.RecordLive do
  use CloudflareDnsWeb, :live_view
  alias CloudflareDns.{DNSCache, DNSValidator, CloudflareClient}

  def mount(params, _session, socket) do
    record_id = Map.get(params, "id")
    action = socket.assigns.live_action

    socket =
      case action do
        :new ->
          socket
          |> assign(:page_title, "Add DNS Record")
          |> assign(:record, nil)
          |> assign(:form, build_form(%{}))
          |> assign(:selected_type, "A")
          |> assign(:record_types, DNSValidator.get_allowed_types())

        :edit ->
          case DNSCache.get_record(record_id) do
            nil ->
              socket
              |> put_flash(:error, "Record not found")
              |> push_navigate(to: "/")

            record ->
              if DNSValidator.can_modify_record?(record) do
                # Extract subdomain from full domain name
                subdomain = String.replace_suffix(record.name, ".#{zone_domain()}", "")

                socket
                |> assign(:page_title, "Edit DNS Record")
                |> assign(:record, record)
                |> assign(
                  :form,
                  build_form(%{
                    "type" => record.type,
                    "name" => subdomain,
                    "content" => record.content,
                    "ttl" => record.ttl
                  })
                )
                |> assign(:selected_type, record.type)
                |> assign(:record_types, DNSValidator.get_allowed_types())
              else
                socket
                |> put_flash(:error, "Cannot edit protected record")
                |> push_navigate(to: "/")
              end
          end
      end

    {:ok, socket}
  end

  defp zone_domain do
    Application.get_env(:cloudflare_dns, :cloudflare_domain)
  end

  def handle_event("type_changed", %{"record" => %{"type" => type}}, socket) do
    # Handle record type change for dynamic UI updates
    {:noreply, assign(socket, :selected_type, type)}
  end

  def handle_event("validate", %{"record" => params}, socket) do
    form = build_form(params, :validate)
    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("save", %{"record" => params}, socket) do
    # Get existing record ID if we're editing
    existing_record_id =
      case socket.assigns.live_action do
        :edit -> socket.assigns.record.id
        _ -> nil
      end

    case DNSValidator.validate_record(params, existing_record_id) do
      {:ok, validated_params} ->
        save_record(socket, socket.assigns.live_action, validated_params)

      {:error, errors} ->
        form = build_form(params, :validate, errors)

        {:noreply,
         socket
         |> assign(:form, form)
         |> put_flash(:error, "Validation failed: #{Enum.join(errors, ", ")}")}
    end
  end

  defp save_record(socket, :new, params) do
    ttl = String.to_integer(params["ttl"] || "1")

    case CloudflareClient.create_dns_record(
           params["type"],
           params["name"],
           params["content"],
           %{comment: "STUDENT", ttl: ttl}
         ) do
      {:ok, _record} ->
        # Build full domain name for flash message
        full_name = "#{params["name"]}.#{zone_domain()}"

        flash_message =
          "#{params["name"]} (#{params["type"]}) record #{full_name} successfully created"

        DNSCache.invalidate_and_refresh()

        {:noreply,
         socket
         |> put_flash(:success, flash_message)
         |> push_navigate(to: "/")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to create record: #{inspect(reason)}")}
    end
  end

  defp save_record(socket, :edit, params) do
    record = socket.assigns.record
    ttl = String.to_integer(params["ttl"] || "1")

    case CloudflareClient.update_dns_record(
           record.id,
           params["type"],
           params["name"],
           params["content"],
           %{comment: record.comment, ttl: ttl}
         ) do
      {:ok, _record} ->
        # Build full domain name for flash message
        full_name = "#{params["name"]}.#{zone_domain()}"

        flash_message =
          "#{params["name"]} (#{params["type"]}) record #{full_name} successfully updated"

        DNSCache.invalidate_and_refresh()

        {:noreply,
         socket
         |> put_flash(:success, flash_message)
         |> push_navigate(to: "/")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to update record: #{inspect(reason)}")}
    end
  end

  defp build_form(params, _action \\ :create, errors \\ []) do
    attrs =
      Map.merge(
        %{
          "type" => "A",
          "name" => "",
          "content" => "",
          "ttl" => "1"
        },
        params
      )

    # Add errors to the form data if any
    form_data =
      if errors != [] do
        Map.put(attrs, "errors", errors)
      else
        attrs
      end

    to_form(form_data, as: :record)
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <!-- Header -->
      <div class="bg-white shadow">
        <div class="px-4 py-6 mx-auto max-w-7xl sm:px-6 lg:px-8">
          <div class="flex items-center">
            <.link navigate="/" class="mr-4 text-gray-400 hover:text-gray-600">
              <.icon name="hero-arrow-left" class="h-6 w-6" />
            </.link>
            <div>
              <h1 class="text-3xl font-bold text-gray-900">{@page_title}</h1>
              <p class="mt-1 text-sm text-gray-600">
                <%= if @live_action == :new do %>
                  Create a new DNS record for {zone_domain()}
                <% else %>
                  Update the DNS record
                <% end %>
              </p>
            </div>
          </div>
        </div>
      </div>

      <div class="px-4 py-6 mx-auto max-w-5xl sm:px-6 lg:px-8">
        <div class="grid grid-cols-1 gap-6 lg:grid-cols-3">
          <!-- Form -->
          <div class="lg:col-span-2">
            <div class="bg-white shadow rounded-lg">
              <div class="px-6 py-4 border-b border-gray-200">
                <h2 class="text-lg font-medium text-gray-900">Record Details</h2>
              </div>
              <div class="px-6 py-4">
                <.form for={@form} phx-submit="save" phx-change="validate">
                  <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
                    <div class="[\&_div.fieldset]:mb-0">
                      <.input
                        field={@form[:type]}
                        type="select"
                        label="Record Type"
                        options={[
                          {"A Record (Points to IP Address)", "A"},
                          {"CNAME Record (Points to Another Domain)", "CNAME"}
                        ]}
                        phx-change="type_changed"
                        required
                        class="w-full select-with-indicator appearance-none rounded-md border border-gray-300 bg-white text-gray-900 pl-4 pr-12 py-2.5 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 focus:ring-2 focus:ring-offset-0"
                      />
                    </div>
                    <div class="[\&_div.fieldset]:mb-0">
                      <.input
                        field={@form[:ttl]}
                        type="select"
                        label="TTL (Time To Live)"
                        options={[
                          {"Auto", "1"},
                          {"5 minutes", "300"},
                          {"15 minutes", "900"},
                          {"30 minutes", "1800"},
                          {"1 hour", "3600"},
                          {"24 hours", "86400"}
                        ]}
                        class="w-full select-with-indicator appearance-none rounded-md border border-gray-300 bg-white text-gray-900 pl-4 pr-12 py-2.5 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 focus:ring-2 focus:ring-offset-0"
                      />
                    </div>
                  </div>

                  <div class="mt-4">
                    <label class="block text-sm font-medium text-gray-900 mb-2">
                      Subdomain Name <span class="text-red-500">*</span>
                    </label>
                    <div class="mt-1 flex rounded-md shadow-sm [\&_div.fieldset]:mb-0 [\&_div.fieldset]:flex-1 [\&_div.fieldset>label]:flex [\&_div.fieldset>label]:w-full [\&_div.fieldset>label]:items-stretch">
                      <.input
                        field={@form[:name]}
                        type="text"
                        placeholder="Enter subdomain (e.g., 'mysite')"
                        class="w-full rounded-l-md border border-r-0 border-gray-300 bg-white text-gray-900 placeholder-gray-500 pl-4 pr-6 py-2.5 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 focus:ring-2 focus:ring-offset-0 sm:min-w-[18rem] md:min-w-[22rem] lg:min-w-[26rem]"
                      />
                      <span class="inline-flex items-center px-4 py-2 rounded-r-md border border-l-0 border-gray-300 bg-gray-100 text-gray-900 text-sm font-medium leading-snug tracking-tight">
                        .{zone_domain()}
                      </span>
                    </div>
                  </div>

                  <div class="mt-4">
                    <label class="block text-sm font-medium text-gray-900 mb-2">
                      Content <span class="text-red-500">*</span>
                    </label>
                    <.input
                      field={@form[:content]}
                      type="text"
                      placeholder={get_content_placeholder(@selected_type)}
                      class="block w-full bg-white text-gray-900 placeholder-gray-500 border border-gray-300 rounded-md px-4 py-3 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 focus:ring-2 focus:ring-offset-0"
                      required
                    />
                  </div>

                  <div class="mt-6 flex justify-end space-x-3">
                    <.link
                      navigate="/"
                      class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
                    >
                      Cancel
                    </.link>
                    <.button
                      type="submit"
                      class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700"
                    >
                      {if @live_action == :new, do: "Create Record", else: "Update Record"}
                    </.button>
                  </div>
                </.form>
              </div>
            </div>
          </div>
          
    <!-- Educational Content -->
          <div class="space-y-6">
            <%= if @selected_type do %>
              <% record_info = Enum.find(@record_types, &(&1.type == @selected_type)) %>
              <%= if record_info do %>
                <div class="bg-blue-50 border border-blue-200 rounded-lg p-4">
                  <div class="flex">
                    <div class="flex-shrink-0">
                      <.icon name="hero-information-circle" class="h-5 w-5 text-blue-400" />
                    </div>
                    <div class="ml-3">
                      <h3 class="text-sm font-medium text-blue-800">
                        {record_info.name} ({record_info.type})
                      </h3>
                      <p class="mt-1 text-sm text-blue-700">
                        {record_info.description}
                      </p>
                      <div class="mt-2">
                        <p class="text-xs font-medium text-blue-800">Use Case:</p>
                        <p class="text-xs text-blue-700">{record_info.use_case}</p>
                      </div>
                      <div class="mt-2">
                        <p class="text-xs font-medium text-blue-800">Example Content:</p>
                        <code class="text-xs bg-blue-100 text-blue-900 px-1 rounded">
                          {record_info.example_content}
                        </code>
                      </div>
                    </div>
                  </div>
                </div>
              <% end %>
            <% end %>
            
    <!-- Restrictions Notice -->
            <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
              <div class="flex">
                <div class="flex-shrink-0">
                  <.icon name="hero-exclamation-triangle" class="h-5 w-5 text-yellow-400" />
                </div>
                <div class="ml-3">
                  <h3 class="text-sm font-medium text-yellow-800">
                    Important Restrictions
                  </h3>
                  <ul class="mt-1 text-sm text-yellow-700 list-disc list-inside space-y-1">
                    <li>Cannot use "www" or root domain "@"</li>
                    <li>No wildcard domains (*.example)</li>
                    <li>No duplicate subdomain names</li>
                    <li>Only A and CNAME records allowed</li>
                    <li>Protected records cannot be modified</li>
                  </ul>
                </div>
              </div>
            </div>
            
    <!-- Tips -->
            <div class="bg-green-50 border border-green-200 rounded-lg p-4">
              <div class="flex">
                <div class="flex-shrink-0">
                  <.icon name="hero-light-bulb" class="h-5 w-5 text-green-400" />
                </div>
                <div class="ml-3">
                  <h3 class="text-sm font-medium text-green-800">
                    Tips for Success
                  </h3>
                  <ul class="mt-1 text-sm text-green-700 list-disc list-inside space-y-1">
                    <li>Use descriptive subdomain names</li>
                    <li>A records need valid IPv4 addresses</li>
                    <li>CNAME records point to other domains</li>
                    <li>TTL "Auto" is usually best for learning</li>
                  </ul>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <CloudflareDnsWeb.Layouts.flash_group flash={@flash} />
    """
  end

  defp get_content_placeholder("A"), do: "192.0.2.1"
  defp get_content_placeholder("CNAME"), do: "example.com"
  defp get_content_placeholder(_), do: "Enter the record content"
end
