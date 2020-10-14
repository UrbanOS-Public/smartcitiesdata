defmodule DiscoveryApi.Test.AuthConnCase.AuthHelper do
  @moduledoc """
  Helper functions and valid values for testing auth things.
  """
  alias DiscoveryApiWeb.Auth.TokenHandler
  alias Auth.TestHelper

  def build_connections() do
    authorized_jwt = TestHelper.valid_jwt()
    revocable_jwt = TestHelper.revocable_jwt()

    authorized_conn = Phoenix.ConnTest.build_conn()
    |> Plug.Test.init_test_session(%{})
    |> TokenHandler.put_session_token(authorized_jwt)

    revocable_conn = Phoenix.ConnTest.build_conn()
    |> Plug.Test.init_test_session(%{})
    |> TokenHandler.put_session_token(revocable_jwt)

    invalid_conn = Phoenix.ConnTest.build_conn()
    |> Plug.Test.init_test_session(%{})
    |> TokenHandler.put_session_token("sdfsadfasdfasdfdaf")

    [
      conn: Phoenix.ConnTest.build_conn(),
      authorized_conn: authorized_conn,
      revocable_conn: revocable_conn,
      invalid_conn: invalid_conn,
      authorized_subject: TestHelper.valid_jwt_sub(),
      revocable_subject: TestHelper.revocable_jwt_sub(),
      invalid_subject: "blaahhhhhh"
    ]
  end

  def setup_jwks() do
    bypass = Bypass.open()
    Bypass.stub(bypass, "GET", "/.well-known/jwks.json", fn conn ->
      Plug.Conn.resp(conn, :ok, Jason.encode!(TestHelper.valid_jwks()))
    end)

    current_config = Application.get_env(:discovery_api, DiscoveryApiWeb.Auth.TokenHandler) || []

    bypassed_config = Keyword.merge(
      current_config,
      [issuer: "http://localhost:#{bypass.port}/"]
    )

    Application.put_env(:discovery_api, DiscoveryApiWeb.Auth.TokenHandler, bypassed_config)

    fn ->
      Application.put_env(:discovery_api, DiscoveryApiWeb.Auth.TokenHandler, current_config)
    end
  end

  def login() do
    login(TestHelper.valid_jwt_sub(), TestHelper.valid_jwt())
  end

  def login(subject, token) do
    user = DiscoveryApi.Test.Helper.create_persisted_user(subject)

    %{status_code: status_code} =
      HTTPoison.post!(
        "http://localhost:4000/api/v1/logged-in",
        "",
        Authorization: "Bearer #{token}",
        "Content-Type": "application/json"
      )

    {user, token, status_code}
  end
end
