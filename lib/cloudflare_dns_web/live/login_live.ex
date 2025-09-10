defmodule CloudflareDnsWeb.LoginLive do
  use CloudflareDnsWeb, :live_view

  def mount(_params, session, socket) do
    # If already authenticated, redirect to dashboard
    if Map.get(session, "authenticated") do
      {:ok, push_navigate(socket, to: "/")}
    else
      {:ok, assign(socket, :form, to_form(%{"password" => ""}, as: :login))}
    end
  end

  defp zone_domain do
    Application.get_env(:cloudflare_dns, :cloudflare_domain)
  end

  def handle_event("submit", %{"login" => %{"password" => _password}}, socket) do
    # Use a regular form submission to handle authentication with session
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
      <div class="max-w-md w-full space-y-8">
        <div>
          <h2 class="mt-6 text-center text-3xl font-extrabold text-gray-900">
            DNS Management Portal
          </h2>
          <p class="mt-2 text-center text-sm text-gray-600">
            Enter the access password to continue
          </p>
        </div>
        <.form for={@form} action="/login" method="post" class="mt-8 space-y-6">
          <div>
            <.input
              field={@form[:password]}
              type="password"
              placeholder="Access Password"
              autocomplete="current-password"
              required
              class="relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 rounded-md focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 focus:z-10 sm:text-sm"
            />
          </div>
          <div>
            <.button
              type="submit"
              class="group relative w-full flex justify-center py-2 px-4 border border-transparent text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
            >
              <.icon name="hero-lock-closed" class="-ml-1 mr-2 h-4 w-4" /> Sign In
            </.button>
          </div>
        </.form>

        <div class="mt-8 bg-blue-50 border border-blue-200 rounded-md p-4">
          <div class="flex">
            <div class="flex-shrink-0">
              <.icon name="hero-information-circle" class="h-5 w-5 text-blue-400" />
            </div>
            <div class="ml-3">
              <h3 class="text-sm font-medium text-blue-800">
                Welcome to DNS Learning Portal
              </h3>
              <div class="mt-2 text-sm text-blue-700">
                <p>
                  This portal allows students to create and manage DNS records for the {zone_domain()} domain.
                </p>
                <ul class="mt-1 list-disc list-inside">
                  <li>Create A records to point subdomains to IP addresses</li>
                  <li>Create CNAME records to create domain aliases</li>
                  <li>View real-time updates as other students make changes</li>
                </ul>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
