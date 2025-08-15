defmodule DiscoveryApiWeb.VisualizationControllerTest do
  use DiscoveryApiWeb.ConnCase
  import Mox

  alias DiscoveryApi.Schemas.Users
  alias DiscoveryApi.Schemas.Visualizations
  alias DiscoveryApi.Schemas.Visualizations.Visualization
  alias DiscoveryApi.Services.PrestoService
  alias DiscoveryApiWeb.Utilities.ModelAccessUtils

  @moduletag timeout: 5000

  @user_id "asdfkjashdflkjhasdkjkadsf"

  @id "abcdefg"
  @title "My title"
  @query "select * from stuff"
  @decoded_chart %{"data" => [], "frames" => [], "layout" => %{}}
  @encoded_chart Jason.encode!(@decoded_chart)

  setup :verify_on_exit!
  setup :set_mox_from_context
  
  setup do
    # Common mocks needed by all tests
    stub(PrestoServiceMock, :is_select_statement?, fn _query -> true end)
    stub(PrestoServiceMock, :get_affected_tables, fn _arg1, _arg2 -> {:ok, []} end)
    stub(ModelMock, :get_all, fn -> [] end)
    
    # Mock modules using :meck since they lack dependency injection  
    modules_to_mock = [ModelAccessUtils, Users, Visualizations]
    
    Enum.each(modules_to_mock, fn module ->
      try do
        :meck.unload(module)
      catch
        _, _ -> :ok
      end
      :meck.new(module, [:passthrough])
    end)
    
    :meck.expect(ModelAccessUtils, :has_access?, fn _arg1, _arg2 -> true end)
    
    # Mock the Guardian resource_from_claims lookup - catch all calls
    valid_jwt_sub = Auth.TestHelper.valid_jwt_sub()
    :meck.expect(Users, :get_user_with_organizations, fn _, _ -> 
      {:ok, %{id: @user_id, subject_id: valid_jwt_sub}}
    end)
    
    
    # Since test_mode: true is set, the SetCurrentUser plug will use TestGuardian
    # which simply checks for :current_user in conn.assigns
    # But we also need to set up Guardian resource for LoadResource plug
    user_resource = %{id: @user_id, subject_id: Auth.TestHelper.valid_jwt_sub()}
    
    authorized_conn = 
      build_conn()
      |> put_req_header("authorization", "Bearer #{Auth.TestHelper.valid_jwt()}")
      |> put_req_header("content-type", "application/json")
      |> Plug.Conn.assign(:current_user, user_resource)
      |> Guardian.Plug.put_current_resource(user_resource)
    
    # For tests that need anonymous access  
    anonymous_conn = 
      build_conn()
      |> put_req_header("content-type", "application/json")

    on_exit(fn ->
      Enum.each(modules_to_mock, fn module ->
        try do
          :meck.unload(module)
        catch
          _, _ -> :ok
        end
      end)
    end)
    
    [
      authorized_conn: authorized_conn,
      anonymous_conn: anonymous_conn,
      authorized_subject: Auth.TestHelper.valid_jwt_sub()
    ]
  end

  describe "with Auth0 auth provider" do
    test "POST /visualization returns CREATED for valid bearer token and visualization setup", %{
      authorized_conn: conn,
      authorized_subject: subject
    } do
      :meck.expect(Users, :get_user_with_organizations, fn ^subject, :subject_id -> {:ok, %{id: @user_id}} end)
      :meck.expect(Visualizations, :get_visualizations_by_owner_id, fn _user_id -> [] end)

      :meck.expect(Visualizations, :create_visualization, fn _arg -> {:ok, %Visualization{public_id: @id, query: @query, title: @title, owner_id: @user_id, chart: @encoded_chart}} end)

      body =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/visualization", ~s({"query": "#{@query}", "title": "#{@title}", "chart": #{@encoded_chart}}))
        |> response(201)
        |> Jason.decode!()

      assert %{
               "query" => @query,
               "title" => @title,
               "id" => @id,
               "allowedActions" => [%{"name" => "update"}, %{"name" => "create_copy"}]
             } = body
    end

    test "DELETE /visualization returns NO CONTENT for valid bearer token and an owned visualization id", %{
      authorized_conn: conn,
      authorized_subject: subject
    } do
      :meck.expect(Users, :get_user_with_organizations, fn user_subject, :subject_id -> {:ok, %{id: @user_id, subject_id: user_subject}} end)

      :meck.expect(Visualizations, :get_visualization_by_id, fn _id ->
        {:ok, %Visualization{public_id: @id, query: @query, title: @title, owner_id: @user_id, chart: @encoded_chart, id: 1}}
      end)

      :meck.expect(Visualizations, :delete_visualization, fn _arg -> {:ok, :does_not_matter} end)

      conn
      |> put_req_header("content-type", "application/json")
      |> delete("/api/v1/visualization/#{@id}")
      |> response(204)
    end

    test "DELETE /visualization returns BAD REQUEST for valid bearer token and an unowned visualization id", %{
      authorized_conn: conn,
      authorized_subject: subject
    } do
      :meck.expect(Users, :get_user_with_organizations, fn ^subject, :subject_id -> {:ok, %{id: @user_id}} end)

      :meck.expect(Visualizations, :get_visualization_by_id, fn _id ->
        {:ok, %Visualization{public_id: @id, query: @query, title: @title, owner_id: "frank", chart: @encoded_chart, id: 1}}
      end)

      # Mox verification happens automatically - delete_visualization should not be called

      conn
      |> put_req_header("content-type", "application/json")
      |> delete("/api/v1/visualization/#{@id}")
      |> response(400)
    end

    test "DELETE /visualization returns BAD REQUEST for non existant visualization id", %{
      authorized_conn: conn,
      authorized_subject: subject
    } do
      :meck.expect(Users, :get_user_with_organizations, fn ^subject, :subject_id -> {:ok, %{id: @user_id}} end)

      :meck.expect(Visualizations, :get_visualization_by_id, fn _id -> {:error, :does_not_matter} end)

      # Mox verification happens automatically - delete_visualization should not be called

      conn
      |> put_req_header("content-type", "application/json")
      |> delete("/api/v1/visualization/#{@id}")
      |> response(400)
    end

    test "GET /visualization/id returns OK for valid bearer token and id", %{
      authorized_conn: conn,
      authorized_subject: subject
    } do
      _datasets = ["123"]
      :meck.expect(Users, :get_user_with_organizations, fn ^subject, :subject_id -> {:ok, %{id: @user_id}} end)

      :meck.expect(Visualizations, :get_visualization_by_id, fn _id ->
        {:ok, %Visualization{public_id: @id, query: @query, title: @title, owner_id: "irrelevant", chart: @encoded_chart, datasets: ["123"]}}
      end)

      # current_user is already assigned in setup

      body =
        conn
        |> get("/api/v1/visualization/#{@id}")
        |> json_response(200)

      assert %{
               "query" => @query,
               "title" => @title,
               "id" => @id,
               "chart" => @decoded_chart,
               "usedDatasets" => datasets
             } = body
    end

    test "GET /visualization/id returns update and create_copy actions when user is owner", %{
      authorized_conn: conn,
      authorized_subject: subject
    } do
      :meck.expect(Users, :get_user_with_organizations, fn ^subject, :subject_id -> {:ok, %{id: @user_id}} end)

      :meck.expect(Visualizations, :get_visualization_by_id, fn _id ->
        {:ok, %Visualization{public_id: @id, query: @query, title: @title, owner_id: @user_id, chart: @encoded_chart}}
      end)


      body =
        conn
        |> get("/api/v1/visualization/#{@id}")
        |> json_response(200)

      assert %{"allowedActions" => [%{"name" => "update"}, %{"name" => "create_copy"}]} = body
    end

    test "GET /visualization/id returns only create_copy action when user is not the owner", %{
      authorized_conn: conn,
      authorized_subject: subject
    } do
      :meck.expect(Users, :get_user_with_organizations, fn ^subject, :subject_id -> {:ok, %{id: @user_id}} end)

      :meck.expect(Visualizations, :get_visualization_by_id, fn _id ->
        {:ok, %Visualization{public_id: @id, query: @query, title: @title, owner_id: "someone else", chart: @encoded_chart}}
      end)


      body =
        conn
        |> get("/api/v1/visualization/#{@id}")
        |> json_response(200)

      assert %{"allowedActions" => [%{"name" => "create_copy"}]} = body
    end

    test "GET /visualization/id returns no allowed actions when no user is signed in", %{
      anonymous_conn: conn
    } do
      :meck.expect(Visualizations, :get_visualization_by_id, fn _id ->
        {:ok, %Visualization{public_id: @id, query: @query, title: @title, owner_id: "someone else", chart: @encoded_chart}}
      end)


      body =
        conn
        |> put_req_header("content-type", "application/json")
        |> get("/api/v1/visualization/#{@id}")
        |> response(200)
        |> Jason.decode!()

      assert %{"allowedActions" => []} = body
    end

    test "GET /visualization/id returns OK but empty chart if it is not decodable", %{
      authorized_conn: conn,
      authorized_subject: subject
    } do
      undecodable_chart = ~s({"data": ]]})
      :meck.expect(Users, :get_user_with_organizations, fn ^subject, :subject_id -> {:ok, %{id: @user_id}} end)

      :meck.expect(Visualizations, :get_visualization_by_id, fn _id ->
        {:ok, %Visualization{public_id: @id, query: @query, title: @title, owner_id: "irrelevant", chart: undecodable_chart}}
      end)


      body =
        conn
        |> get("/api/v1/visualization/#{@id}")
        |> json_response(200)

      assert %{
               "query" => @query,
               "title" => @title,
               "id" => @id,
               "chart" => %{}
             } = body
    end

    test "GET /visualization/id returns OK but empty chart when chart is nil", %{
      authorized_conn: conn,
      authorized_subject: subject
    } do
      :meck.expect(Users, :get_user_with_organizations, fn ^subject, :subject_id -> {:ok, %{id: @user_id}} end)

      :meck.expect(Visualizations, :get_visualization_by_id, fn _id ->
        {:ok, %Visualization{public_id: @id, query: @query, title: @title, owner_id: "irrelevant", chart: nil}}
      end)


      body =
        conn
        |> get("/api/v1/visualization/#{@id}")
        |> json_response(200)

      assert %{
               "query" => @query,
               "title" => @title,
               "id" => @id,
               "chart" => %{}
             } = body
    end

    test "GET /visualization gets all visualizations for user with valid bearer token", %{
      authorized_conn: conn,
      authorized_subject: subject
    } do
      :meck.expect(Users, :get_user_with_organizations, fn ^subject, :subject_id -> {:ok, %{id: @user_id}} end)

      :meck.expect(Visualizations, :get_visualizations_by_owner_id, fn _user_id ->
        [
          %Visualization{public_id: "1", query: "blah", title: "blah blah", owner_id: @user_id, chart: "{}"},
          %Visualization{public_id: "2", query: "blah", title: "blah blah", owner_id: @user_id, chart: "{}"}
        ]
      end)

      body =
        conn
        |> put_req_header("content-type", "application/json")
        |> get("/api/v1/visualization")
        |> response(200)
        |> Jason.decode!()

      assert [
               %{"id" => "1", "allowedActions" => [%{"name" => "update"}, %{"name" => "create_copy"}]},
               %{"id" => "2", "allowedActions" => [%{"name" => "update"}, %{"name" => "create_copy"}]}
             ] = body
    end

    test "GET /visualization returns UNAUTHENTICATED with no user signed in", %{
      anonymous_conn: conn
    } do
      assert %{"message" => "Unauthorized"} ==
               conn
               |> put_req_header("content-type", "application/json")
               |> get("/api/v1/visualization")
               |> response(401)
               |> Jason.decode!()
    end
  end
end