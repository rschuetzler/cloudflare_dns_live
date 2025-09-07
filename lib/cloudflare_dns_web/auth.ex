defmodule CloudflareDnsWeb.Auth do
  @moduledoc """
  Authentication module for password-based access control.
  """
  
  import Plug.Conn
  import Phoenix.Controller

  @doc """
  Plug to check if user is authenticated.
  """
  def require_auth(conn, _opts) do
    case get_session(conn, :authenticated) do
      true -> conn
      _ -> redirect_to_login(conn)
    end
  end

  @doc """
  Init callback for the plug.
  """
  def init(opts), do: opts

  @doc """
  Call callback for the plug.
  """
  def call(conn, :require_auth) do
    require_auth(conn, [])
  end

  @doc """
  Authenticates a user with the provided password.
  """
  @spec authenticate(String.t()) :: boolean()
  def authenticate(password) do
    expected_password = get_access_password()
    password == expected_password
  end

  @doc """
  Marks the user as authenticated in the session.
  """
  @spec login(Plug.Conn.t()) :: Plug.Conn.t()
  def login(conn) do
    put_session(conn, :authenticated, true)
  end

  @doc """
  Logs out the user by clearing the session.
  """
  @spec logout(Plug.Conn.t()) :: Plug.Conn.t()
  def logout(conn) do
    clear_session(conn)
  end

  @doc """
  Checks if the current user is authenticated.
  """
  @spec authenticated?(Plug.Conn.t()) :: boolean()
  def authenticated?(conn) do
    get_session(conn, :authenticated) == true
  end

  # Private functions

  defp get_access_password do
    System.get_env("ACCESS_PASSWORD") || 
      raise "ACCESS_PASSWORD environment variable not set"
  end

  defp redirect_to_login(conn) do
    conn
    |> redirect(to: "/login")
    |> halt()
  end
end