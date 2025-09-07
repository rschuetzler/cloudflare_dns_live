defmodule CloudflareDnsWeb.AuthTest do
  use ExUnit.Case, async: true
  alias CloudflareDnsWeb.Auth

  describe "authenticate/1" do
    test "returns true for correct password" do
      # Set test password
      System.put_env("ACCESS_PASSWORD", "test123")
      
      assert Auth.authenticate("test123")
    end

    test "returns false for incorrect password" do
      System.put_env("ACCESS_PASSWORD", "test123")
      
      refute Auth.authenticate("wrong")
    end

    test "raises error when password not configured" do
      System.delete_env("ACCESS_PASSWORD")
      
      assert_raise RuntimeError, ~r/ACCESS_PASSWORD environment variable not set/, fn ->
        Auth.authenticate("any")
      end
    end
  end
end