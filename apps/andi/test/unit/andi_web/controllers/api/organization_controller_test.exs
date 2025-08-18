defmodule AndiWeb.API.OrganizationControllerTest do
  use ExUnit.Case
  use AndiWeb.Test.AuthConnCase.UnitCase

  alias SmartCity.Organization
  alias SmartCity.UserOrganizationAssociate
  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.Services.OrgStore
  alias Andi.InputSchemas.Organizations

  import SmartCity.Event

  @moduletag timeout: 5000

  @instance_name Andi.instance_name()
  @route "/api/v1/organization"
  @get_orgs_route "/api/v1/organizations"

  setup do
    # Set up :meck for modules without dependency injection
    modules_to_mock = [OrgStore, Andi.Schemas.AuditEvents]
    
    Enum.each(modules_to_mock, fn module ->
      try do
        :meck.unload(module)
      catch
        _, _ -> :ok
      end
      
      try do
        :meck.new(module, [:passthrough])
      catch
        :error, {:already_started, _} -> :ok
      end
    end)
    
    :meck.expect(OrgStore, :get, fn _ -> {:ok, nil} end)
    :meck.expect(Andi.Schemas.AuditEvents, :log_audit_event, fn _, _, _ -> %{} end)
    
    on_exit(fn ->
      Enum.each(modules_to_mock, fn module ->
        try do
          :meck.unload(module)
        catch
          _, _ -> :ok
        end
      end)
    end)

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

    {:ok, request: request, message: message, expected_orgs: get_example_orgs()}
  end

  describe "post /api/ with valid data" do
    setup %{conn: conn, request: request} do
      # Set up :meck for this test group
      modules = [Brook.Event, Organizations]
      Enum.each(modules, fn module ->
        try do
          :meck.unload(module)
        catch
          _, _ -> :ok
        end
        
        try do
          :meck.new(module, [:passthrough])
        catch
          :error, {:already_started, _} -> :ok
        end
      end)
      
      :meck.expect(Brook.Event, :send, fn @instance_name, _, :andi, _ -> :ok end)
      :meck.expect(Organizations, :get, fn _ -> nil end)
      :meck.expect(Organizations, :is_unique?, fn _, _ -> true end)
      
      on_exit(fn ->
        Enum.each(modules, fn module ->
          try do
            :meck.unload(module)
          catch
            _, _ -> :ok
          end
        end)
      end)
      
      [conn: post(conn, @route, request)]
    end

    test "returns 201", %{conn: conn, message: %{"orgName" => name}} do
      response = json_response(conn, 201)

      assert response["orgName"] == name
      assert uuid?(response["id"])
    end

    test "writes organization to event stream", %{message: _message} do
      assert :meck.num_calls(Brook.Event, :send, [@instance_name, :_, :andi, :_]) == 1
    end

    test "writes event to audit_event table", %{message: _message} do
      assert :meck.num_calls(Andi.Schemas.AuditEvents, :log_audit_event, [:api, organization_update(), :_]) == 1
    end
  end

  describe "post /api/ with valid data and imported id" do
    setup %{conn: conn} do
      # Set up :meck for this test group
      modules = [Organizations, OrgStore]
      Enum.each(modules, fn module ->
        try do
          :meck.unload(module)
        catch
          _, _ -> :ok
        end
        
        try do
          :meck.new(module, [:passthrough])
        catch
          :error, {:already_started, _} -> :ok
        end
      end)
      
      :meck.expect(Organizations, :get, fn _ -> nil end)
      :meck.expect(Organizations, :update, fn _ -> :ok end)
      :meck.expect(Organizations, :update, fn _, _ -> :ok end)
      :meck.expect(Organizations, :is_unique?, fn _, _ -> true end)
      :meck.expect(OrgStore, :update, fn _ -> :ok end)
      
      on_exit(fn ->
        Enum.each(modules, fn module ->
          try do
            :meck.unload(module)
          catch
            _, _ -> :ok
          end
        end)
      end)
      
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
    # Set up :meck for Organizations
    try do
      :meck.unload(Organizations)
    catch
      _, _ -> :ok
    end
    
    try do
      :meck.new(Organizations, [:passthrough])
    catch
      :error, {:already_started, _} -> :ok
    end
    
    :meck.expect(Organizations, :get, fn _ -> nil end)
    :meck.expect(Organizations, :is_unique?, fn _, _ -> true end)
    
    conn = post(conn, @route)
    assert json_response(conn, 500) =~ "Unable to process your request"
    
    :meck.unload(Organizations)
  end

  @tag capture_log: true
  test "post /api/ with improperly shaped data returns 500", %{conn: conn} do
    # Set up :meck for Organizations
    try do
      :meck.unload(Organizations)
    catch
      _, _ -> :ok
    end
    
    try do
      :meck.new(Organizations, [:passthrough])
    catch
      :error, {:already_started, _} -> :ok
    end
    
    :meck.expect(Organizations, :get, fn _ -> nil end)
    :meck.expect(Organizations, :is_unique?, fn _, _ -> true end)
    
    conn = post(conn, @route, %{"invalidData" => 2})
    assert json_response(conn, 500) =~ "Unable to process your request"
    
    :meck.unload(Organizations)
  end

  @tag capture_log: true
  test "post /api/ with blank id should create org with generated id", %{conn: conn} do
    # Set up :meck for Organizations and OrgStore
    modules = [Organizations, OrgStore]
    Enum.each(modules, fn module ->
      try do
        :meck.unload(module)
      catch
        _, _ -> :ok
      end
      
      try do
        :meck.new(module, [:passthrough])
      catch
        :error, {:already_started, _} -> :ok
      end
    end)
    
    :meck.expect(Organizations, :get, fn _ -> nil end)
    :meck.expect(Organizations, :update, fn _ -> :ok end)
    :meck.expect(Organizations, :is_unique?, fn _, _ -> true end)
    :meck.expect(OrgStore, :update, fn _ -> :ok end)
    
    conn = post(conn, @route, %{"id" => "", "orgName" => "blankIDOrg", "orgTitle" => "Blank ID Org Title"})

    response = json_response(conn, 201)

    assert response["orgName"] == "blankIDOrg"
    assert response["id"] != ""
    
    Enum.each(modules, fn module ->
      try do
        :meck.unload(module)
      catch
        _, _ -> :ok
      end
    end)
  end

  describe "id already exists" do
    setup do
      # Set up :meck for this test group
      modules = [Brook.Event, OrgStore, Organizations]
      Enum.each(modules, fn module ->
        try do
          :meck.unload(module)
        catch
          _, _ -> :ok
        end
        
        try do
          :meck.new(module, [:passthrough])
        catch
          :error, {:already_started, _} -> :ok
        end
      end)
      
      :meck.expect(Brook.Event, :send, fn @instance_name, _, :andi, _ -> :ok end)
      :meck.expect(OrgStore, :get, fn _ -> {:ok, %Organization{}} end)
      :meck.expect(Organizations, :get, fn _ -> %{} end)
      :meck.expect(Organizations, :is_unique?, fn _, _ -> true end)
      
      on_exit(fn ->
        Enum.each(modules, fn module ->
          try do
            :meck.unload(module)
          catch
            _, _ -> :ok
          end
        end)
      end)
      
      :ok
    end

    @tag capture_log: true
    test "post /api/v1/organization fails with explanation", %{conn: conn, request: req} do
      post(conn, @route, req)
      assert :meck.num_calls(Brook.Event, :send, [@instance_name, :_, :andi, :_]) == 0
    end
  end

  describe "GET orgs from /api/v1/organization" do
    test "returns a 200", %{conn: conn, expected_orgs: expected_orgs} do
      # Set up :meck for OrgStore
      try do
        :meck.unload(OrgStore)
      catch
        _, _ -> :ok
      end
      
      try do
        :meck.new(OrgStore, [:passthrough])
      catch
        :error, {:already_started, _} -> :ok
      end
      
      :meck.expect(OrgStore, :get_all, fn -> {:ok, expected_orgs} end)
      
      actual_orgs =
        conn
        |> get(@get_orgs_route)
        |> json_response(200)

      assert MapSet.new(expected_orgs) == MapSet.new(actual_orgs)
      
      :meck.unload(OrgStore)
    end
  end

  describe "organization/:org_id/users/add" do
    @org_id "org_id"
    @org TDG.create_organization(%{id: @org_id})

    setup do
      # Set up :meck for this test group
      modules = [OrgStore, Brook.Event]
      Enum.each(modules, fn module ->
        try do
          :meck.unload(module)
        catch
          _, _ -> :ok
        end
        
        try do
          :meck.new(module, [:passthrough])
        catch
          :error, {:already_started, _} -> :ok
        end
      end)
      
      :meck.expect(OrgStore, :get, fn @org_id -> {:ok, @org} end)
      :meck.expect(Brook.Event, :send, fn @instance_name, _, :andi, _ -> :ok end)
      
      on_exit(fn ->
        Enum.each(modules, fn module ->
          try do
            :meck.unload(module)
          catch
            _, _ -> :ok
          end
        end)
      end)
      
      users = %{"users" => [1, 2]}

      %{org: @org, users: users}
    end

    test "returns a 200", %{conn: conn, org: org, users: users} do
      # Set up :meck for Andi.Schemas.User
      try do
        :meck.unload(Andi.Schemas.User)
      catch
        _, _ -> :ok
      end
      
      try do
        :meck.new(Andi.Schemas.User, [:passthrough])
      catch
        :error, {:already_started, _} -> :ok
      end
      
      :meck.expect(Andi.Schemas.User, :get_by_subject_id, fn _ -> %{subject_id: "N/A", email: "example.com"} end)
      
      actual =
        conn
        |> post("/api/v1/organization/#{org.id}/users/add", users)
        |> json_response(200)

      assert actual == users
      
      :meck.unload(Andi.Schemas.User)
    end

    test "returns a 400 if the organization doesn't exist", %{conn: conn, users: users} do
      # Set up :meck for Andi.Schemas.User and OrgStore
      modules = [Andi.Schemas.User, OrgStore]
      Enum.each(modules, fn module ->
        try do
          :meck.unload(module)
        catch
          _, _ -> :ok
        end
        
        try do
          :meck.new(module, [:passthrough])
        catch
          :error, {:already_started, _} -> :ok
        end
      end)
      
      :meck.expect(Andi.Schemas.User, :get_by_subject_id, fn _ -> %{subject_id: "N/A", email: "example.com"} end)
      :meck.expect(OrgStore, :get, fn _ -> {:ok, nil} end)
      
      org_id = 111

      actual =
        conn
        |> post("/api/v1/organization/#{org_id}/users/add", users)
        |> json_response(400)

      assert actual == "The organization #{org_id} does not exist"
      assert :meck.num_calls(Brook.Event, :send, [@instance_name, :_, :andi, :_]) == 0
      
      Enum.each(modules, fn module ->
        try do
          :meck.unload(module)
        catch
          _, _ -> :ok
        end
      end)
    end

    test "sends a user:organization:associate event", %{conn: conn, org: org, users: users} do
      {:ok, %{subject_id: expected_1_subject_id, email: expected_1_email} = expected_1} =
        UserOrganizationAssociate.new(%{subject_id: 1, org_id: org.id, email: "bob@bob.com"})

      {:ok, %{subject_id: expected_2_subject_id, email: expected_2_email} = expected_2} =
        UserOrganizationAssociate.new(%{subject_id: 2, org_id: org.id, email: "bob2@bob.com"})

      # Set up :meck for Andi.Schemas.User
      try do
        :meck.unload(Andi.Schemas.User)
      catch
        _, _ -> :ok
      end
      
      try do
        :meck.new(Andi.Schemas.User, [:passthrough])
      catch
        :error, {:already_started, _} -> :ok
      end
      
      :meck.expect(Andi.Schemas.User, :get_by_subject_id, fn
        ^expected_1_subject_id -> %{subject_id: expected_1_subject_id, email: expected_1_email}
        ^expected_2_subject_id -> %{subject_id: expected_2_subject_id, email: expected_2_email}
      end)
      
      conn
      |> post("/api/v1/organization/#{org.id}/users/add", users)
      |> json_response(200)

      assert :meck.num_calls(Brook.Event, :send, [@instance_name, :_, :andi, expected_1]) == 1
      assert :meck.num_calls(Brook.Event, :send, [@instance_name, :_, :andi, expected_2]) == 1
      assert :meck.num_calls(Andi.Schemas.AuditEvents, :log_audit_event, [:api, user_organization_associate(), expected_1]) == 1
      assert :meck.num_calls(Andi.Schemas.AuditEvents, :log_audit_event, [:api, user_organization_associate(), expected_2]) == 1
      
      :meck.unload(Andi.Schemas.User)
    end

    test "returns 400 if a user is not found", %{conn: conn, org: org, users: users} do
      {:ok, %{subject_id: expected_1_subject_id, email: expected_1_email} = expected_1} =
        UserOrganizationAssociate.new(%{subject_id: 1, org_id: org.id, email: "bob@bob.com"})

      {:ok, %{subject_id: expected_2_subject_id, email: _expected_2_email} = expected_2} =
        UserOrganizationAssociate.new(%{subject_id: 2, org_id: org.id, email: "bob2@bob.com"})

      # Set up :meck for Andi.Schemas.User
      try do
        :meck.unload(Andi.Schemas.User)
      catch
        _, _ -> :ok
      end
      
      try do
        :meck.new(Andi.Schemas.User, [:passthrough])
      catch
        :error, {:already_started, _} -> :ok
      end
      
      :meck.expect(Andi.Schemas.User, :get_by_subject_id, fn
        ^expected_1_subject_id -> nil
        ^expected_2_subject_id -> %{subject_id: expected_2_subject_id, email: expected_1_email}
      end)
      
      conn
      |> post("/api/v1/organization/#{org.id}/users/add", users)
      |> json_response(400)

      assert :meck.num_calls(Brook.Event, :send, [@instance_name, :_, :andi, expected_1]) == 0
      assert :meck.num_calls(Brook.Event, :send, [@instance_name, :_, :andi, expected_2]) == 0
      
      :meck.unload(Andi.Schemas.User)
    end

    @tag capture_log: true
    test "returns a 500 if unable to get organizations through Brook", %{conn: conn} do
      # Set up :meck for Andi.Schemas.User and OrgStore
      modules = [Andi.Schemas.User, OrgStore]
      Enum.each(modules, fn module ->
        try do
          :meck.unload(module)
        catch
          _, _ -> :ok
        end
        
        try do
          :meck.new(module, [:passthrough])
        catch
          :error, {:already_started, _} -> :ok
        end
      end)
      
      :meck.expect(Andi.Schemas.User, :get_by_subject_id, fn _ -> %{subject_id: "N/A", email: "example.com"} end)
      :meck.expect(OrgStore, :get, fn _ -> {:error, "bad stuff happened"} end)
      
      actual =
        conn
        |> post("/api/v1/organization/222/users/add", %{"users" => [1, 2]})
        |> json_response(500)

      assert actual == "Internal Server Error"
      assert :meck.num_calls(Brook.Event, :send, [@instance_name, :_, :andi, :_]) == 0
      
      Enum.each(modules, fn module ->
        try do
          :meck.unload(module)
        catch
          _, _ -> :ok
        end
      end)
    end

    @tag capture_log: true
    test "returns a 500 if unable to send events", %{conn: conn, org: org} do
      # Set up :meck for Andi.Schemas.User and Brook.Event
      modules = [Andi.Schemas.User, Brook.Event]
      Enum.each(modules, fn module ->
        try do
          :meck.unload(module)
        catch
          _, _ -> :ok
        end
        
        try do
          :meck.new(module, [:passthrough])
        catch
          :error, {:already_started, _} -> :ok
        end
      end)
      
      :meck.expect(Andi.Schemas.User, :get_by_subject_id, fn _ -> %{subject_id: "N/A", email: "example.com"} end)
      :meck.expect(Brook.Event, :send, fn @instance_name, _, :andi, _ -> {:error, "unable to send event"} end)
      
      actual =
        conn
        |> post("/api/v1/organization/#{org.id}/users/add", %{"users" => [1, 2]})
        |> json_response(500)

      assert actual == "Internal Server Error"
      
      Enum.each(modules, fn module ->
        try do
          :meck.unload(module)
        catch
          _, _ -> :ok
        end
      end)
    end
  end

  defp uuid?(str) do
    case UUID.info(str) do
      {:ok, _} -> true
      _ -> false
    end
  end

  defp get_example_orgs() do
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

    [expected_org_1, expected_org_2]
  end
end
