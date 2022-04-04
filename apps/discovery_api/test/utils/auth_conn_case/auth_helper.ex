defmodule DiscoveryApi.Test.AuthConnCase.AuthHelper do
  @moduledoc """
  Helper functions and valid values for testing auth things.
  """
  alias Auth.TestHelper

  def build_connections() do
    authorized_jwt = TestHelper.valid_jwt()
    revocable_jwt = TestHelper.revocable_jwt()

    conn =
      Phoenix.ConnTest.build_conn()
      |> set_content_type()

    authorized_conn =
      Phoenix.ConnTest.build_conn()
      |> put_bearer_token(authorized_jwt)
      |> set_content_type()

    revocable_conn =
      Phoenix.ConnTest.build_conn()
      |> put_bearer_token(revocable_jwt)
      |> set_content_type()

    invalid_conn =
      Phoenix.ConnTest.build_conn()
      |> put_bearer_token("sdfsadfasdfasdfdaf")
      |> set_content_type()

    [
      conn: conn,
      anonymous_conn: conn,
      authorized_conn: authorized_conn,
      revocable_conn: revocable_conn,
      invalid_conn: invalid_conn,
      authorized_subject: TestHelper.valid_jwt_sub(),
      revocable_subject: TestHelper.revocable_jwt_sub(),
      invalid_subject: "blaahhhhhh",
      authorized_token: TestHelper.valid_jwt()
    ]
  end

  def setup_jwks() do
    bypass = Bypass.open()

    Bypass.stub(bypass, "GET", "/.well-known/jwks.json", fn conn ->
      Plug.Conn.resp(conn, :ok, Jason.encode!(TestHelper.valid_jwks()))
    end)

    Bypass.stub(bypass, "GET", "/userinfo", fn conn ->
      Plug.Conn.resp(conn, :ok, Jason.encode!(%{"email" => "x@y.z", name: "xyz"}))
    end)

    current_config = Application.get_env(:discovery_api, DiscoveryApiWeb.Auth.TokenHandler) || []

    bypassed_config =
      Keyword.merge(
        current_config,
        issuer: "http://localhost:#{bypass.port}/"
      )

    Application.put_env(:discovery_api, DiscoveryApiWeb.Auth.TokenHandler, bypassed_config)

    {
      fn ->
        Application.put_env(:discovery_api, DiscoveryApiWeb.Auth.TokenHandler, current_config)
      end,
      bypass
    }
  end

  defp put_bearer_token(conn, token) do
    Plug.Conn.put_req_header(conn, "authorization", "Bearer #{token}")
  end

  defp set_content_type(conn) do
    Plug.Conn.put_req_header(conn, "content-type", "application/json")
  end
end
