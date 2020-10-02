defmodule AndiWeb.AuthTest do
  @moduledoc false
  use ExUnit.Case
  use AndiWeb.ConnCase

  setup_all do
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

    [signing_opts: signing_opts]
  end

  test "redirects users who are not authenticated to login page" do
    conn = build_conn() |> get("/datasets")

    assert conn.status == 302
    assert conn.resp_body =~ "/auth/auth0?prompt=login\""
  end

  test "redirects users not assigned to proper role back to login page with error message", %{conn: conn, signing_opts: signing_opts} do
    jwt = valid_jwt()

    conn =
      conn
      |> Map.put(:secret_key_base, "blahblahblahblahblahblahblahblahblahblahblahblahblahblahblahblahblahblahblahblahblahblahblahblahblah")
      |> Plug.Session.call(signing_opts)
      |> Plug.Conn.fetch_session()
      |> AndiWeb.Auth.TokenHandler.put_session_token(jwt)
      |> Guardian.Plug.VerifySession.call(module: AndiWeb.Auth.TokenHandler, error_handler: AndiWeb.Auth.ErrorHandler, claims: %{})
      |> get("/datasets")

    assert conn.status == 302
    assert conn.resp_body =~ "error_message=Unauthorized\""
  end

  def valid_jwt() do
    "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6Ik9ESXlSRU5ETkVZelFrVkVNakF5TnpFNFJUTkNNVE0yUVROR1JqVTJOVVUzUXpaRFFVUTFPUSJ9.eyJpc3MiOiJodHRwczovL3NtYXJ0Y29sdW1idXNvcy1kZW1vLmF1dGgwLmNvbS8iLCJzdWIiOiJhdXRoMHw1ZDdhNTI3MTc2ZmIxNjBkOGQ5YjJlM2QiLCJhdWQiOlsiZGlzY292ZXJ5X2FwaSIsImh0dHBzOi8vc21hcnRjb2x1bWJ1c29zLWRlbW8uYXV0aDAuY29tL3VzZXJpbmZvIl0sImlhdCI6MTU2ODk5NTAyOSwiZXhwIjoxNTY4OTk1MDg5LCJhenAiOiJzZmU1Zlp6RlhzdjVnSVJYejhWM3prUjdpYVpCTXZMMCIsInNjb3BlIjoib3BlbmlkIHByb2ZpbGUgZW1haWwifQ.P6mLUyh9R5GVRgkGXSiOSLGHm4LM9Xi25dEKMUZqLSeRFgOKgTTHrV_SRtHXWgjbCUlI_2tobHWk0C1hIb2_CfkIhCTXsKwt81Q0iKy-L56fsPax5ZNnVl31uiueMPqKQ5M-41AHtDnGe1P4VsJDoBLUNr8C_yUQRJWA1V9E2LKZsmnauRtAm_S89T7KCNxhA9M75zCcm--dLwtu9PpjlQHfQvbxTT0Ujh0uguJXgrOpmlamO8Fc_cYYiiOr2Jw_Dfk5U0Xkz0gswYc11Jli5Klz1P0iZJGwr6ctgGoZzPd55biUGlyNeR_MAgBEmemMBV5Utk_lE7sx0JnrAMhIUw"
  end
end
