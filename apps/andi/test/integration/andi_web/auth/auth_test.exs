defmodule AndiWeb.AuthTest do
  @moduledoc false
  use ExUnit.Case
  use AndiWeb.ConnCase

  alias Andi.Test.AuthHelper

  setup_all do
    Ecto.Adapters.SQL.Sandbox.checkout(Andi.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Andi.Repo, {:shared, self()})

    default_opts = [
      store: :cookie,
      key: "secretkey",
      encryption_salt: "encrypted cookie salt",
      signing_salt: "signing salt"
    ]

    signing_opts = Plug.Session.init(Keyword.put(default_opts, :encrypt, false))

    really_far_in_the_future = 3_000_000_000_000

    config = [
      allowed_algos: ["RS256"],
      issuer: "https://smartcolumbusos-demo.auth0.com/",
      secret_fetcher: Auth.Auth0.SecretFetcher,
      verify_issuer: true,
      allowed_drift: really_far_in_the_future
    ]

    Application.put_env(:andi, AndiWeb.Auth.TokenHandler, config)

    conn =
      build_conn()
      |> Map.put(:secret_key_base, "blahblahblahblahblahblahblahblahblahblahblahblahblahblahblahblahblahblahblahblahblahblahblahblahblah")

    [conn: conn, signing_opts: signing_opts]
  end

  test "redirects users who are not authenticated to login page" do
    conn = build_conn() |> get("/datasets")

    assert conn.status == 302
    assert conn.resp_body =~ "/auth/auth0?prompt=login\""
  end

  test "redirects users not assigned to proper role back to login page with error message", %{conn: conn, signing_opts: signing_opts} do
    jwt = AuthHelper.valid_jwt_unauthorized_roles()

    conn =
      conn
      |> Plug.Session.call(signing_opts)
      |> Plug.Conn.fetch_session()
      |> AndiWeb.Auth.TokenHandler.put_session_token(jwt)
      |> Guardian.Plug.VerifySession.call(module: AndiWeb.Auth.TokenHandler, error_handler: AndiWeb.Auth.ErrorHandler, claims: %{})
      |> get("/datasets")

    assert conn.status == 302
    assert conn.resp_body =~ "error_message=Unauthorized\""
  end

  test "returns 200 when user is authenticated and has correct roles", %{conn: conn, signing_opts: signing_opts} do
    jwt = AuthHelper.valid_jwt()

    conn =
      conn
      |> Plug.Session.call(signing_opts)
      |> Plug.Conn.fetch_session()
      |> AndiWeb.Auth.TokenHandler.put_session_token(jwt)
      |> Plug.Conn.put_session(:user_id, "TEST")
      |> Guardian.Plug.VerifySession.call(module: AndiWeb.Auth.TokenHandler, error_handler: AndiWeb.Auth.ErrorHandler, claims: %{})
      |> get("/datasets")

    assert conn.status == 200
  end
end
