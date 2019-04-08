defmodule AndiWeb.OrganizationControllerTest do
  use ExUnit.Case
  use Placebo
  use AndiWeb.ConnCase

  @route "/api/v1/organization"
  @ou Application.get_env(:andi, :ldap_env_ou)
  alias SmartCity.Organization

  setup do
    allow(Paddle.authenticate(any(), any()), return: :ok)
    allow(Organization.get(any()), return: {:error, %Organization.NotFound{}}, meck_options: [:passthrough])

    request = %{
      "orgName" => "myOrg",
      "orgTitle" => "My Org Title"
    }

    message = %{
      "orgName" => "myOrg",
      "orgTitle" => "My Org Title",
      "description" => nil,
      "homepage" => nil,
      "logoUrl" => nil,
      "dn" => "cn=myOrg,dc=foo,dc=bar"
    }

    {:ok, request: request, message: message}
  end

  describe "post /api/ with valid data" do
    setup %{conn: conn, request: request} do
      allow(Organization.write(any()), return: {:ok, "id"}, meck_options: [:passthrough])
      allow(Paddle.add(any(), any()), return: :ok)
      [conn: post(conn, @route, request)]
    end

    test "returns 201", %{conn: conn, message: %{"orgName" => name}} do
      response = json_response(conn, 201)

      assert response["orgName"] == name
      assert uuid?(response["id"])
    end

    test "writes organization to registry", %{message: message} do
      struct = capture(Organization.write(any()), 1)
      assert struct.orgName == message["orgName"]
      assert uuid?(struct.id)
    end

    test "writes organization to LDAP", %{message: %{"orgName" => name}} do
      attrs = [objectClass: ["top", "groupofnames"], cn: name, member: "cn=admin"]
      assert_called(Paddle.add([cn: name, ou: @ou], attrs), once())
    end
  end

  describe "post /api/ with valid data and imported id" do
    setup %{conn: conn} do
      allow(Organization.write(any()), return: {:ok, "id"}, meck_options: [:passthrough])
      allow(Paddle.add(any(), any()), return: :ok)

      req_with_id = %{
        "id" => "123",
        "orgName" => "yourOrg",
        "orgTitle" => "Your Org Title"
      }

      [conn: post(conn, @route, req_with_id)]
    end

    test "passed in id is used", %{conn: conn} do
      response = json_response(conn, 201)

      assert response["orgName"] == "yourOrg"
      assert response["id"] == "123"
    end
  end

  describe "failed write to LDAP" do
    setup do
      allow(Organization.write(any()), return: {:ok, "id"}, meck_options: [:passthrough])
      allow(Paddle.add(any(), any()), return: {:error, :reason})
      :ok
    end

    @tag capture_log: true
    test "returns 500", %{conn: conn, request: req} do
      conn = post(conn, @route, req)
      assert json_response(conn, 500) =~ "Unable to process your request"
    end

    @tag capture_log: true
    test "never persists organization to registry", %{conn: conn, request: req} do
      post(conn, @route, req)
      refute_called(Organization.write(any()))
    end
  end

  describe "failed write to Redis" do
    setup %{conn: conn, request: req} do
      allow(Organization.write(any()), return: {:error, :reason}, meck_options: [:passthrough])
      allow(Paddle.add(any(), any()), return: :ok, meck_options: [:passthrough])
      allow(Paddle.delete(any()), return: :ok)

      [conn: post(conn, @route, req), request: req]
    end

    @tag capture_log: true
    test "removes organization from LDAP" do
      assert_called(Paddle.delete(cn: "myOrg", ou: @ou))
    end
  end

  @tag capture_log: true
  test "post /api/ without data returns 500", %{conn: conn} do
    conn = post(conn, @route)
    assert json_response(conn, 500) =~ "Unable to process your request"
  end

  @tag capture_log: true
  test "post /api/ with improperly shaped data returns 500", %{conn: conn} do
    conn = post(conn, @route, %{"invalidData" => 2})
    assert json_response(conn, 500) =~ "Unable to process your request"
  end

  describe "id already exists" do
    setup do
      allow(Organization.get(any()), return: {:ok, %Organization{}}, meck_options: [:passthrough])
      :ok
    end

    @tag capture_log: true
    test "post /api/v1/organization fails with explanation", %{conn: conn, request: req} do
      post(conn, @route, req)
      refute_called(Organization.write(any()))
    end
  end

  defp uuid?(str) do
    case UUID.info(str) do
      {:ok, _} -> true
      _ -> false
    end
  end
end
