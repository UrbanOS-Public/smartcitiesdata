defmodule Andi.Test.AuthConnCase.AuthHelper do
  @moduledoc """
  Helper functions and valid values for testing auth things.
  """
  alias AndiWeb.Auth.TokenHandler
  alias Auth.TestHelper

  def build_connections() do
    curator_jwt = TestHelper.valid_jwt()
    public_jwt = TestHelper.valid_public_jwt()
    unauthorized_jwt = TestHelper.valid_jwt_unauthorized_roles()

    curator_conn =
      Phoenix.ConnTest.build_conn()
      |> Plug.Test.init_test_session(%{})
      |> TokenHandler.put_session_token(curator_jwt)

    public_conn =
      Phoenix.ConnTest.build_conn()
      |> Plug.Test.init_test_session(%{})
      |> TokenHandler.put_session_token(public_jwt)

    unauthorized_conn =
      Phoenix.ConnTest.build_conn()
      |> Plug.Test.init_test_session(%{})
      |> TokenHandler.put_session_token(unauthorized_jwt)

    [
      conn: curator_conn,
      curator_conn: curator_conn,
      public_conn: public_conn,
      unauthorized_conn: unauthorized_conn,
      curator_subject: TestHelper.valid_jwt_sub(),
      public_subject: TestHelper.valid_public_sub()
    ]
  end

  def setup_jwks() do
    bypass = Bypass.open()

    Bypass.stub(bypass, "GET", "/.well-known/jwks.json", fn conn ->
      Plug.Conn.resp(conn, :ok, Jason.encode!(TestHelper.valid_jwks()))
    end)

    current_config = Application.get_env(:andi, AndiWeb.Auth.TokenHandler) || []

    bypassed_config =
      Keyword.merge(
        current_config,
        issuer: "http://localhost:#{bypass.port}/"
      )

    Application.put_env(:andi, AndiWeb.Auth.TokenHandler, bypassed_config)

    fn ->
      Application.put_env(:andi, AndiWeb.Auth.TokenHandler, current_config)
    end
  end
end
