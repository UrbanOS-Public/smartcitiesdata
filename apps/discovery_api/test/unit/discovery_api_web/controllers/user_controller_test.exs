defmodule DiscoveryApiWeb.UserControllerTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo

  alias DiscoveryApi.Auth.GuardianConfigurator
  alias DiscoveryApi.Auth.Auth0.CachedJWKS
  alias DiscoveryApiWeb.Auth.TokenHandler
  alias DiscoveryApi.Test.AuthHelper
  alias DiscoveryApi.Schemas.Users
  alias DiscoveryApi.Schemas.Users.User

  @valid_jwt AuthHelper.valid_jwt()
  @user_info_body Jason.encode!(%{"email" => "x@y.z"})

  describe "POST /logged-in with Auth0 auth provider" do
    setup do
      secret_key = Application.get_env(:discovery_api, TokenHandler) |> Keyword.get(:secret_key)
      GuardianConfigurator.configure(issuer: AuthHelper.valid_issuer())

      jwks = AuthHelper.valid_jwks()
      CachedJWKS.set(jwks)

      bypass = Bypass.open()

      really_far_in_the_future = 3_000_000_000_000
      AuthHelper.set_allowed_guardian_drift(really_far_in_the_future)
      Application.put_env(:discovery_api, :user_info_endpoint, "http://localhost:#{bypass.port}/userinfo")

      allow(TokenHandler.on_verify(any(), any(), any()), exec: &AuthHelper.guardian_verify_passthrough/3, meck_options: [:passthrough])
      allow(Users.create_or_update(any(), %{email: "x@y.z"}), return: {:ok, %User{}})

      on_exit(fn ->
        AuthHelper.set_allowed_guardian_drift(0)
        GuardianConfigurator.configure(secret_key: secret_key)
      end)

      %{bypass: bypass}
    end

    test "returns OK for valid bearer token", %{conn: conn, bypass: bypass} do
      Bypass.stub(bypass, "GET", "/userinfo", fn conn -> Plug.Conn.resp(conn, :ok, @user_info_body) end)

      conn
      |> put_req_header("authorization", "Bearer #{@valid_jwt}")
      |> post("/api/v1/logged-in")
      |> response(200)
    end

    test "retrieves user info using validated token", %{conn: conn, bypass: bypass} do
      Bypass.expect(bypass, "GET", "/userinfo", fn conn ->
        authorization_header = Enum.find(conn.req_headers, fn header -> elem(header, 0) == "authorization" end)
        assert authorization_header != nil

        assert "Bearer #{@valid_jwt}" == elem(authorization_header, 1)
        Plug.Conn.resp(conn, :ok, @user_info_body)
      end)

      conn
      |> put_req_header("authorization", "Bearer #{@valid_jwt}")
      |> post("/api/v1/logged-in")
    end

    test "creates/updates user with the fetched user info", %{conn: conn, bypass: bypass} do
      Bypass.stub(bypass, "GET", "/userinfo", fn conn -> Plug.Conn.resp(conn, :ok, @user_info_body) end)

      conn
      |> put_req_header("authorization", "Bearer #{@valid_jwt}")
      |> post("/api/v1/logged-in")
      |> response(200)

      assert_called(Users.create_or_update(AuthHelper.valid_jwt_sub(), %{email: "x@y.z"}))
    end

    @moduletag capture_log: true
    test "returns internal server error when user cannot be saved", %{conn: conn, bypass: bypass} do
      allow(Users.create_or_update(any(), %{email: "error_causing@e.mail"}), return: {:error, :bad_things})

      Bypass.stub(bypass, "GET", "/userinfo", fn conn -> Plug.Conn.resp(conn, :ok, Jason.encode!(%{"email" => "error_causing@e.mail"})) end)

      conn
      |> put_req_header("authorization", "Bearer #{@valid_jwt}")
      |> post("/api/v1/logged-in")
      |> response(500)
    end

    @moduletag capture_log: true
    test "returns internal server error when user info cannot be parsed", %{conn: conn, bypass: bypass} do
      Bypass.stub(bypass, "GET", "/userinfo", fn conn -> Plug.Conn.resp(conn, :ok, "this is not user info... it's not even json") end)

      conn
      |> put_req_header("authorization", "Bearer #{@valid_jwt}")
      |> post("/api/v1/logged-in")
      |> response(500)
    end
  end
end
