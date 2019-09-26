defmodule DiscoveryApiWeb.UserControllerTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo

  alias DiscoveryApi.Test.AuthHelper
  alias DiscoveryApi.Schemas.Users
  alias DiscoveryApi.Schemas.Users.User

  @valid_jwt AuthHelper.valid_jwt()
  @user_info_body Jason.encode!(%{"name" => "x@y.z"})

  describe "POST /logged-in" do
    setup do
      jwks = AuthHelper.valid_jwks()
      Application.put_env(:discovery_api, :jwks_cache, jwks)

      bypass = Bypass.open()

      really_far_in_the_future = 3_000_000_000_000
      AuthHelper.set_allowed_guardian_drift(really_far_in_the_future)
      Application.put_env(:discovery_api, :user_info_endpoint, "http://localhost:#{bypass.port}/userinfo")

      allow(Users.create_or_update(any(), %{username: "x@y.z"}), return: {:ok, %User{}})

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

      assert_called(Users.create_or_update(AuthHelper.valid_jwt_sub(), %{username: "x@y.z"}))
    end

    @moduletag capture_log: true
    test "returns internal server error when user cannot be saved", %{conn: conn, bypass: bypass} do
      allow(Users.create_or_update(any(), %{username: "name_that_causes_error"}), return: {:error, :bad_things})

      Bypass.stub(bypass, "GET", "/userinfo", fn conn -> Plug.Conn.resp(conn, :ok, Jason.encode!(%{"name" => "name_that_causes_error"})) end)

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
