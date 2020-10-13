defmodule AndiWeb.AuthConnCase do
  @moduledoc """
  This module produced authorized and unauthorized connections for testing against Andi
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      use Phoenix.ConnTest
      alias AndiWeb.Router.Helpers, as: Routes

      @endpoint AndiWeb.Endpoint
    end
  end

  alias Andi.Test.AuthHelper
  alias AndiWeb.Auth.TokenHandler

  setup _tags do
    authorized_jwt = AuthHelper.valid_jwt()
    unauthorized_jwt = AuthHelper.valid_jwt_unauthorized_roles()

    authorized_conn = Phoenix.ConnTest.build_conn()
    |> Plug.Test.init_test_session(%{})
    |> TokenHandler.put_session_token(authorized_jwt)

    unauthorized_conn = Phoenix.ConnTest.build_conn()
    |> Plug.Test.init_test_session(%{})
    |> TokenHandler.put_session_token(unauthorized_jwt)

    [
      conn: authorized_conn,
      authorized_conn: authorized_conn,
      unauthorized_conn: unauthorized_conn
    ]
  end

  setup_all do
    bypass = Bypass.open()
    Bypass.stub(bypass, "GET", "/.well-known/jwks.json", fn conn ->
      Plug.Conn.resp(conn, :ok, Jason.encode!(AuthHelper.valid_jwks()))
    end)

    current_config = Application.get_env(:andi, AndiWeb.Auth.TokenHandler)

    bypassed_config = Keyword.merge(
      current_config,
      [issuer: "http://localhost:#{bypass.port}/"]
    )

    Application.put_env(:andi, AndiWeb.Auth.TokenHandler, bypassed_config)

    on_exit(fn ->
      Application.put_env(:andi, AndiWeb.Auth.TokenHandler, current_config)
    end)

    :ok
  end
end
