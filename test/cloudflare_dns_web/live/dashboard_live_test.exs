defmodule CloudflareDnsWeb.DashboardLiveTest do
  use CloudflareDnsWeb.ConnCase
  import Phoenix.LiveViewTest

  # Mock the DNS cache for testing
  defmodule MockDNSCache do
    alias CloudflareDns.CloudflareClient.DNSRecord

    def get_all_records do
      [
        %DNSRecord{
          id: "1",
          type: "A",
          name: "test.is404.net",
          content: "192.0.2.1",
          ttl: 1,
          comment: "STUDENT"
        },
        %DNSRecord{
          id: "2", 
          type: "CNAME",
          name: "alias.is404.net",
          content: "example.com",
          ttl: 1,
          comment: "KEEP"
        }
      ]
    end

    def search_records(query) do
      get_all_records()
      |> Enum.filter(fn record ->
        String.contains?(String.downcase(record.name), String.downcase(query))
      end)
    end

    def subscribe, do: :ok
  end

  setup do
    # Mock the DNS cache module for tests
    Application.put_env(:cloudflare_dns, :dns_cache_module, MockDNSCache)
    
    conn = 
      build_conn()
      |> init_test_session(%{authenticated: true})
    
    {:ok, conn: conn}
  end

  test "renders dashboard with DNS records", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")
    
    assert has_element?(view, "h1", "DNS Management Portal")
    assert has_element?(view, "td", "test.is404.net") 
    assert has_element?(view, "td", "alias.is404.net")
  end

  test "shows correct record types and statuses", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")
    
    # Check for A record badge
    assert has_element?(view, "span", "A")
    # Check for CNAME record badge  
    assert has_element?(view, "span", "CNAME")
    # Check for student status
    assert has_element?(view, "span", "Student")
    # Check for protected status
    assert has_element?(view, "span", "Protected")
  end

  test "search functionality works", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")
    
    # Search for "test"
    view
    |> form("form", search: %{query: "test"})
    |> render_submit()
    
    # Should still show the test record
    assert has_element?(view, "td", "test.is404.net")
    # Should not show the alias record
    refute has_element?(view, "td", "alias.is404.net")
  end

  test "shows protected record actions correctly", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")
    
    # Protected record should show "Protected" instead of edit/delete buttons
    protected_row = element(view, "tr", "alias.is404.net")
    assert has_element?(protected_row, "span", "Protected")
    refute has_element?(protected_row, "a", "Edit")
    refute has_element?(protected_row, "button", "Delete")
  end

  test "shows student record actions correctly", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")
    
    # Student record should show edit and delete buttons
    student_row = element(view, "tr", "test.is404.net") 
    assert has_element?(student_row, "a", "Edit")
    assert has_element?(student_row, "button", "Delete")
  end

  test "redirects to login when not authenticated", %{conn: _conn} do
    # Create conn without authentication
    unauth_conn = build_conn()
    
    {:error, {:redirect, %{to: "/login"}}} = live(unauth_conn, "/")
  end
end