defmodule CloudflareDnsWeb.DashboardLive do
  use CloudflareDnsWeb, :live_view
  alias CloudflareDns.{DNSCache, DNSValidator, CloudflareClient}

  @per_page 20

  def mount(_params, _session, socket) do
    # Subscribe to DNS record updates
    DNSCache.subscribe()
    
    socket = 
      socket
      |> assign(:search_query, "")
      |> assign(:page, 1)
      |> assign(:per_page, @per_page)
      |> load_records()
    
    {:ok, socket}
  end

  def handle_params(params, _url, socket) do
    search_query = Map.get(params, "search", "")
    page = String.to_integer(Map.get(params, "page", "1"))
    
    socket = 
      socket
      |> assign(:search_query, search_query)
      |> assign(:page, page)
      |> load_records()
    
    {:noreply, socket}
  end

  def handle_event("search", %{"query" => query}, socket) do
    {:noreply, 
     socket
     |> push_patch(to: "/?search=#{URI.encode(query)}&page=1")}
  end

  def handle_event("clear_search", _params, socket) do
    {:noreply, push_patch(socket, to: "/?page=1")}
  end

  def handle_event("delete_record", %{"id" => id}, socket) do
    case DNSCache.get_record(id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Record not found")}
        
      record ->
        if DNSValidator.can_modify_record?(record) do
          case CloudflareClient.delete_dns_record(id) do
            :ok ->
              # Extract subdomain from full domain name for flash message
              subdomain = String.replace_suffix(record.name, ".is404.net", "")
              flash_message = "#{subdomain} (#{record.type}) record #{record.name} successfully deleted"
              
              DNSCache.invalidate_and_refresh()
              {:noreply, 
               socket
               |> put_flash(:warning, flash_message)
               |> load_records()}
               
            {:error, reason} ->
              {:noreply, put_flash(socket, :error, "Failed to delete record: #{inspect(reason)}")}
          end
        else
          {:noreply, put_flash(socket, :error, "Cannot delete protected record")}
        end
    end
  end

  def handle_info({:dns_records_updated, _records}, socket) do
    {:noreply, load_records(socket)}
  end

  defp load_records(socket) do
    all_records = if socket.assigns.search_query != "" do
      DNSCache.search_records(socket.assigns.search_query)
    else
      DNSCache.get_all_records()
    end
    
    total_records = length(all_records)
    total_pages = ceil(total_records / @per_page)
    offset = (socket.assigns.page - 1) * @per_page
    
    records = all_records
              |> Enum.sort_by(& &1.name)
              |> Enum.slice(offset, @per_page)
    
    socket
    |> assign(:records, records)
    |> assign(:total_records, total_records)
    |> assign(:total_pages, total_pages)
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <!-- Header -->
      <div class="bg-white shadow">
        <div class="px-4 py-6 mx-auto max-w-7xl sm:px-6 lg:px-8">
          <div class="flex justify-between items-center">
            <div>
              <h1 class="text-3xl font-bold text-gray-900">DNS Management Portal</h1>
              <p class="mt-1 text-sm text-gray-600">Manage DNS records for is404.net domain</p>
            </div>
            <div class="flex space-x-4">
              <.link navigate="/records/new" class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700">
                <.icon name="hero-plus" class="-ml-1 mr-2 h-4 w-4" />
                Add Record
              </.link>
              <form method="post" action="/logout" class="inline">
                <button type="submit" class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50">
                  <.icon name="hero-arrow-right-on-rectangle" class="-ml-1 mr-2 h-4 w-4" />
                  Logout
                </button>
              </form>
            </div>
          </div>
        </div>
      </div>

      <!-- Search and Filters -->
      <div class="px-4 py-6 mx-auto max-w-7xl sm:px-6 lg:px-8">
        <div class="mb-6">
          <.form for={%{}} as={:search} phx-submit="search" class="flex gap-4 items-center">
            <div class="flex-1">
              <.input 
                name="query" 
                type="text" 
                value={@search_query}
                placeholder="Search records by name, content, or type..."
                class="block w-full bg-white text-gray-900 placeholder-gray-500 border border-gray-300 rounded-md px-3 py-2 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 focus:ring-1 h-10"
              />
            </div>
            <div class="flex gap-2">
              <.button type="submit" class="inline-flex items-center px-4 py-2 text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 shadow-sm border border-transparent h-10">
                <.icon name="hero-magnifying-glass" class="-ml-1 mr-2 h-4 w-4" />
                Search
              </.button>
              <.button 
                :if={@search_query != ""}
                type="button" 
                phx-click="clear_search" 
                class="inline-flex items-center px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 hover:bg-gray-50 rounded-md h-10"
              >
                Clear
              </.button>
            </div>
          </.form>
        </div>

        <!-- Records Stats -->
        <div class="mb-6 text-sm text-gray-600">
          Showing <span class="font-medium"><%= length(@records) %></span> of 
          <span class="font-medium"><%= @total_records %></span> records
          <%= if @search_query != "" do %>
            matching "<span class="font-medium"><%= @search_query %></span>"
          <% end %>
        </div>

        <!-- Records Table -->
        <div class="bg-white shadow overflow-hidden sm:rounded-lg">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Name</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Type</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Content</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">TTL</th>
                <th class="relative px-6 py-3"><span class="sr-only">Actions</span></th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <tr :for={record <- @records} class="hover:bg-gray-50">
                <td class="px-6 py-4 whitespace-nowrap">
                  <div class="text-sm font-medium text-gray-900"><%= record.name %></div>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <span class={[
                    "inline-flex px-2 py-1 text-xs font-semibold rounded-full",
                    if(record.type == "A", do: "bg-green-100 text-green-800", else: "bg-blue-100 text-blue-800")
                  ]}>
                    <%= record.type %>
                  </span>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  <%= record.content %>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  <%= if record.ttl == 1, do: "Auto", else: record.ttl %>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                  <%= if DNSValidator.can_modify_record?(record) do %>
                    <div class="flex space-x-2">
                      <.link navigate={"/records/#{record.id}/edit"} class="text-indigo-600 hover:text-indigo-900">
                        Edit
                      </.link>
                      <button 
                        phx-click="delete_record" 
                        phx-value-id={record.id}
                        data-confirm="Are you sure you want to delete this DNS record?"
                        class="text-red-600 hover:text-red-900"
                      >
                        Delete
                      </button>
                    </div>
                  <% else %>
                    <span class="text-gray-400">Protected</span>
                  <% end %>
                </td>
              </tr>
            </tbody>
          </table>

          <%= if @records == [] do %>
            <div class="text-center py-12">
              <.icon name="hero-circle-stack" class="mx-auto h-12 w-12 text-gray-400" />
              <h3 class="mt-2 text-sm font-medium text-gray-900">No DNS records found</h3>
              <p class="mt-1 text-sm text-gray-500">
                <%= if @search_query != "" do %>
                  Try adjusting your search criteria.
                <% else %>
                  Get started by creating your first DNS record.
                <% end %>
              </p>
              <div class="mt-6">
                <.link 
                  navigate="/records/new" 
                  class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700"
                >
                  <.icon name="hero-plus" class="-ml-1 mr-2 h-5 w-5" />
                  Add DNS Record
                </.link>
              </div>
            </div>
          <% end %>
        </div>

        <!-- Pagination -->
        <%= if @total_pages > 1 do %>
          <div class="flex items-center justify-between mt-6">
            <div class="flex-1 flex justify-between sm:hidden">
              <%= if @page > 1 do %>
                <.link 
                  patch={"/?search=#{URI.encode(@search_query)}&page=#{@page - 1}"}
                  class="relative inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
                >
                  Previous
                </.link>
              <% else %>
                <span></span>
              <% end %>
              
              <%= if @page < @total_pages do %>
                <.link 
                  patch={"/?search=#{URI.encode(@search_query)}&page=#{@page + 1}"}
                  class="ml-3 relative inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
                >
                  Next
                </.link>
              <% end %>
            </div>
            
            <div class="hidden sm:flex-1 sm:flex sm:items-center sm:justify-between">
              <div>
                <p class="text-sm text-gray-700">
                  Showing page <span class="font-medium"><%= @page %></span> of <span class="font-medium"><%= @total_pages %></span>
                </p>
              </div>
              <div>
                <nav class="relative z-0 inline-flex rounded-md shadow-sm -space-x-px">
                  <%= if @page > 1 do %>
                    <.link 
                      patch={"/?search=#{URI.encode(@search_query)}&page=#{@page - 1}"}
                      class="relative inline-flex items-center px-2 py-2 rounded-l-md border border-gray-300 bg-white text-sm font-medium text-gray-500 hover:bg-gray-50"
                    >
                      Previous
                    </.link>
                  <% end %>
                  
                  <%= if @page < @total_pages do %>
                    <.link 
                      patch={"/?search=#{URI.encode(@search_query)}&page=#{@page + 1}"}
                      class="relative inline-flex items-center px-2 py-2 rounded-r-md border border-gray-300 bg-white text-sm font-medium text-gray-500 hover:bg-gray-50"
                    >
                      Next
                    </.link>
                  <% end %>
                </nav>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    
    <CloudflareDnsWeb.Layouts.flash_group flash={@flash} />
    """
  end
end