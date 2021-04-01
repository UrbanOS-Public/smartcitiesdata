defmodule AndiWeb.API.OrganizationControllerTest do
  use ExUnit.Case
  use Placebo
  use AndiWeb.Test.AuthConnCase.UnitCase

  @route "/api/v1/organization"
  @get_orgs_route "/api/v1/organizations"
  alias SmartCity.Organization
  alias SmartCity.UserOrganizationAssociate
  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.Services.OrgStore
  alias Andi.InputSchemas.Organizations

  @instance_name Andi.instance_name()

  setup do
    allow(OrgStore.get(any()), return: {:ok, nil}, meck_options: [:passthrough])

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

    expected_org_1 = TDG.create_organization(%{})

    expected_org_1 =
      expected_org_1
      |> Jason.encode!()
      |> Jason.decode!()

    expected_org_2 = TDG.create_organization(%{})

    expected_org_2 =
      expected_org_2
      |> Jason.encode!()
      |> Jason.decode!()

    expected_orgs = [expected_org_1, expected_org_2]

    allow(OrgStore.get_all(),
      return: {:ok, [expected_org_1, expected_org_2]},
      meck_options: [:passthrough]
    )

    {:ok, request: request, message: message, expected_orgs: expected_orgs}
  end

  describe "post /api/ with valid data" do
    setup %{conn: conn, request: request} do
      allow(Brook.Event.send(@instance_name, any(), :andi, any()), return: :ok, meck_options: [:passthrough])
      allow(Organizations.get(any()), return: nil)
      allow(Organizations.is_unique?(any(), any()), return: true)
      [conn: post(conn, @route, request)]
    end

    test "returns 201", %{conn: conn, message: %{"orgName" => name}} do
      response = json_response(conn, 201)

      assert response["orgName"] == name
      assert uuid?(response["id"])
    end

    test "writes organization to event stream", %{message: _message} do
      assert_called(Brook.Event.send(@instance_name, any(), :andi, any()), once())
    end
  end

  describe "post /api/ with valid data and imported id" do
    setup %{conn: conn} do
      allow(Organizations.get(any()), return: nil)
      allow(Organizations.update(any()), return: :ok)
      allow(Organizations.update(any(), any()), return: :ok)
      allow(OrgStore.update(any()), return: :ok)
      allow(Organizations.is_unique?(any(), any()), return: true)

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

  @tag capture_log: true
  test "post /api/ without data returns 500", %{conn: conn} do
    allow(Organizations.get(any()), return: nil)
    allow(Organizations.is_unique?(any(), any()), return: true)

    conn = post(conn, @route)
    assert json_response(conn, 500) =~ "Unable to process your request"
  end

  @tag capture_log: true
  test "post /api/ with improperly shaped data returns 500", %{conn: conn} do
    allow(Organizations.get(any()), return: nil)
    allow(Organizations.is_unique?(any(), any()), return: true)

    conn = post(conn, @route, %{"invalidData" => 2})
    assert json_response(conn, 500) =~ "Unable to process your request"
  end

  @tag capture_log: true
  test "post /api/ with blank id should create org with generated id", %{conn: conn} do
    allow(Organizations.get(any()), return: nil)
    allow(Organizations.update(any()), return: :ok)
    allow(Organizations.is_unique?(any(), any()), return: true)
    allow(OrgStore.update(any()), return: :ok)

    conn = post(conn, @route, %{"id" => "", "orgName" => "blankIDOrg", "orgTitle" => "Blank ID Org Title"})

    response = json_response(conn, 201)

    assert response["orgName"] == "blankIDOrg"
    assert response["id"] != ""
  end

  describe "id already exists" do
    setup do
      allow(Brook.Event.send(@instance_name, any(), :andi, any()), return: :ok, meck_options: [:passthrough])
      allow(OrgStore.get(any()), return: {:ok, %Organization{}}, meck_options: [:passthrough])
      allow(Organizations.get(any()), return: %{})
      allow(Organizations.is_unique?(any(), any()), return: true)
      :ok
    end

    @tag capture_log: true
    test "post /api/v1/organization fails with explanation", %{conn: conn, request: req} do
      post(conn, @route, req)
      refute_called(Brook.Event.send(@instance_name, any(), :andi, any()), once())
    end
  end

  describe "GET orgs from /api/v1/organization" do
    setup %{conn: conn, request: request} do
      [conn: get(conn, @get_orgs_route, request)]
    end

    test "returns a 200", %{conn: conn, expected_orgs: expected_orgs} do
      actual_orgs =
        conn
        |> json_response(200)

      assert MapSet.new(expected_orgs) == MapSet.new(actual_orgs)
    end
  end

  describe "organization/:org_id/users/add" do
    setup do
      org = TDG.create_organization(%{})

      allow(OrgStore.get(org.id),
        return: {:ok, org},
        meck_options: [:passthrough]
      )

      allow(Brook.Event.send(@instance_name, any(), :andi, any()),
        return: :ok,
        meck_options: [:passthrough]
      )

      users = %{"users" => [1, 2]}

      %{org: org, users: users}
    end

    test "returns a 200", %{conn: conn, org: org, users: users} do
      actual =
        conn
        |> post("/api/v1/organization/#{org.id}/users/add", users)
        |> json_response(200)

      assert actual == users
    end

    test "returns a 400 if the organization doesn't exist", %{conn: conn, users: users} do
      allow(OrgStore.get(any()),
        return: {:ok, nil},
        meck_options: [:passthrough]
      )

      org_id = 111

      actual =
        conn
        |> post("/api/v1/organization/#{org_id}/users/add", users)
        |> json_response(400)

      assert actual == "The organization #{org_id} does not exist"
      refute_called(Brook.Event.send(@instance_name, any(), :andi, any()))
    end

    test "sends a user:organization:associate event", %{conn: conn, org: org, users: users} do
      {:ok, expected_1} = UserOrganizationAssociate.new(%{subject_id: 1, org_id: org.id, email: "bob@bob.com"})
      {:ok, expected_2} = UserOrganizationAssociate.new(%{subject_id: 2, org_id: org.id, email: "bob2@bob.com"})
      allow(Andi.Schemas.User.get_by_subject_id(expected_1.subject_id), return: %{subject_id: expected_1.subject_id, email: expected_1.email})
      allow(Andi.Schemas.User.get_by_subject_id(expected_2.subject_id), return: %{subject_id: expected_2.subject_id, email: expected_2.email})

      conn
      |> post("/api/v1/organization/#{org.id}/users/add", users)
      |> json_response(200)

      assert_called(Brook.Event.send(@instance_name, any(), :andi, expected_1), once())
      assert_called(Brook.Event.send(@instance_name, any(), :andi, expected_2), once())
    end

    @tag capture_log: true
    test "returns a 500 if unable to get organizations through Brook", %{conn: conn} do
      allow(OrgStore.get(any()),
        return: {:error, "bad stuff happened"},
        meck_options: [:passthrough]
      )

      actual =
        conn
        |> post("/api/v1/organization/222/users/add", %{"users" => [1, 2]})
        |> json_response(500)

      assert actual == "Internal Server Error"
      refute_called(Brook.Event.send(@instance_name, any(), :andi, any()))
    end

    @tag capture_log: true
    test "returns a 500 if unable to send events", %{conn: conn, org: org} do
      allow(Brook.Event.send(@instance_name, any(), :andi, any()),
        return: {:error, "unable to send event"},
        meck_options: [:passthrough]
      )

      actual =
        conn
        |> post("/api/v1/organization/#{org.id}/users/add", %{"users" => [1, 2]})
        |> json_response(500)

      assert actual == "Internal Server Error"
    end
  end

  defp uuid?(str) do
    case UUID.info(str) do
      {:ok, _} -> true
      _ -> false
    end
  end
end
