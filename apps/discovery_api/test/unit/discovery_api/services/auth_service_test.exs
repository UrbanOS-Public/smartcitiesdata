defmodule DiscoveryApi.Services.AuthServiceTest do
  use DiscoveryApiWeb.Test.AuthConnCase.UnitCase
  use Placebo

  import SmartCity.Event, only: [user_login: 0]
  alias DiscoveryApi.Schemas.Users
  alias DiscoveryApi.Services.AuthService
  alias Auth.TestHelper

  @instance_name DiscoveryApi.instance_name()

  setup %{auth_conn_case: auth_conn_case} do
    auth_conn_case.disable_revocation_list.()
    Brook.Test.register(@instance_name)
    :ok
  end

  describe "auth service test" do
    test "returns unauthorized error for invalid bearer token", %{authorized_conn: conn, bypass: bypass} do
      Bypass.stub(bypass, "GET", "/userinfo", fn conn ->
        Plug.Conn.resp(conn, 500, Jason.encode!(%{body: %{"error" => "error"}}))
      end)

      expect(Guardian.Plug.current_token(conn), return: "bad token")

      {:error, reason} = AuthService.create_logged_in_user(conn)

      assert reason == "Unauthorized"
    end

    test "returns internal server error when user info cannot be parsed", %{authorized_conn: conn, bypass: bypass} do
      Bypass.stub(bypass, "GET", "/userinfo", fn conn ->
        Plug.Conn.resp(conn, :ok, "this is not user info... it's not even json")
      end)

      {:error, reason} = AuthService.create_logged_in_user(conn)

      assert reason == "Internal Server Error"
    end

    test "returns internal server error when user cannot be saved", %{authorized_conn: conn, bypass: bypass} do
      Bypass.stub(bypass, "GET", "/userinfo", fn conn ->
        Plug.Conn.resp(conn, :ok, Jason.encode!(%{"email" => "x@y.z", "name" => "xyz"}))
      end)

      expect(Guardian.Plug.current_claims(any()), return: %{"sub" => "testUserName"})
      expect(Users.create_or_update("testUserName", %{email: "x@y.z", name: "xyz"}), return: "Unknown Error")

      {:error, reason} = AuthService.create_logged_in_user(conn)

      assert reason == "Internal Server Error"
    end

    test "returns updated conn and saves user data on success", %{authorized_conn: authorized_conn, bypass: bypass, authorized_token: token} do
      subject = "testUserName"
      smart_user = "smrtUser"
      test_user = "testUser"
      email = "x@y.z"
      name = "xyz"

      Bypass.stub(bypass, "GET", "/userinfo", fn conn ->
        authorization_header = Enum.find(authorized_conn.req_headers, fn header -> elem(header, 0) == "authorization" end)
        assert authorization_header != nil
        assert "Bearer #{token}" == elem(authorization_header, 1)
        Plug.Conn.resp(conn, :ok, Jason.encode!(%{"email" => email, "name" => name}))
      end)

      expect(Guardian.Plug.current_claims(any()), return: %{"sub" => subject})
      expect(Users.create_or_update(subject, %{email: email, name: name}), return: {:ok, test_user})
      expect(SmartCity.User.new(any()), return: {:ok, smart_user})
      expect(Brook.Event.send(@instance_name, user_login(), any(), smart_user), return: :ok)

      {:ok, new_conn} = AuthService.create_logged_in_user(authorized_conn)

      expected_new_conn = Guardian.Plug.put_current_resource(new_conn, test_user)

      assert new_conn == expected_new_conn
    end
  end
end
