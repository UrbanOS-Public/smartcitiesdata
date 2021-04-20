defmodule DiscoveryApiWeb.UserControllerTest do
  use DiscoveryApiWeb.Test.AuthConnCase.UnitCase
  use Placebo

  import SmartCity.Event, only: [user_login: 0]

  alias DiscoveryApi.Schemas.Users

  @instance_name DiscoveryApi.instance_name()

  setup %{auth_conn_case: auth_conn_case} do
    auth_conn_case.disable_revocation_list.()
    auth_conn_case.disable_user_addition.()
    allow(Brook.Event.send(@instance_name, user_login(), any(), any()), return: :ok)
    :ok
  end

  describe "POST /logged-in with Auth0 auth provider" do
    test "returns OK for valid bearer token", %{authorized_conn: conn} do
      conn
      |> post("/api/v1/logged-in")
      |> response(200)
    end

    test "retrieves user info using validated token", %{authorized_conn: conn, authorized_token: token, bypass: bypass} do
      Bypass.expect(bypass, "GET", "/userinfo", fn conn ->
        authorization_header = Enum.find(conn.req_headers, fn header -> elem(header, 0) == "authorization" end)
        assert authorization_header != nil

        assert "Bearer #{token}" == elem(authorization_header, 1)
        Plug.Conn.resp(conn, :ok, Jason.encode!(%{"email" => "a@b.c"}))
      end)

      conn
      |> post("/api/v1/logged-in")
    end

    test "creates/updates user with the fetched user info", %{authorized_conn: conn, authorized_subject: subject} do
      conn
      |> post("/api/v1/logged-in")
      |> response(200)

      assert_called(Users.create_or_update(subject, %{email: "x@y.z"}))
    end

    @moduletag capture_log: true
    test "returns internal server error when user cannot be saved", %{authorized_conn: conn, bypass: bypass} do
      allow(Users.create_or_update(any(), %{email: "error_causing@e.mail"}), return: {:error, :bad_things})

      Bypass.stub(bypass, "GET", "/userinfo", fn conn -> Plug.Conn.resp(conn, :ok, Jason.encode!(%{"email" => "error_causing@e.mail"})) end)

      conn
      |> post("/api/v1/logged-in")
      |> response(500)
    end

    @moduletag capture_log: true
    test "returns internal server error when user info cannot be parsed", %{authorized_conn: conn, bypass: bypass} do
      Bypass.stub(bypass, "GET", "/userinfo", fn conn -> Plug.Conn.resp(conn, :ok, "this is not user info... it's not even json") end)

      conn
      |> post("/api/v1/logged-in")
      |> response(500)
    end

    test "sends user:login brook event on success", %{authorized_conn: conn} do
      conn
      |> post("/api/v1/logged-in")
      |> response(200)

      assert_called(Brook.Event.send(@instance_name, user_login(), any(), any()))
    end
  end
end
