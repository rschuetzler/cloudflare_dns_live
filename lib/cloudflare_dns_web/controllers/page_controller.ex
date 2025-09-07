defmodule CloudflareDnsWeb.PageController do
  use CloudflareDnsWeb, :controller
  alias CloudflareDnsWeb.Auth

  def home(conn, _params) do
    render(conn, :home)
  end

  def login(conn, %{"login" => %{"password" => password}}) do
    if Auth.authenticate(password) do
      conn
      |> Auth.login()
      |> put_flash(:info, "Successfully logged in!")
      |> redirect(to: "/")
    else
      conn
      |> put_flash(:error, "Invalid password")
      |> redirect(to: "/login")
    end
  end

  def logout(conn, _params) do
    conn
    |> Auth.logout()
    |> put_flash(:info, "Successfully logged out")
    |> redirect(to: "/login")
  end
end
