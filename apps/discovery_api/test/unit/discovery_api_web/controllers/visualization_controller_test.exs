defmodule DiscoveryApiWeb.VisualizationControllerTest do
  use DiscoveryApiWeb.Test.AuthConnCase.UnitCase
  import Mox

  alias DiscoveryApi.Schemas.Users
  alias DiscoveryApi.Schemas.Visualizations
  alias DiscoveryApi.Schemas.Visualizations.Visualization
  alias DiscoveryApi.Services.PrestoService
  alias DiscoveryApiWeb.Utilities.ModelAccessUtils

  @user_id "asdfkjashdflkjhasdkjkadsf"

  @id "abcdefg"
  @title "My title"
  @query "select * from stuff"
  @decoded_chart %{"data" => [], "frames" => [], "layout" => %{}}
  @encoded_chart Jason.encode!(@decoded_chart)

  setup %{auth_conn_case: auth_conn_case} do
    auth_conn_case.disable_revocation_list.()
    :ok
  end

  setup :verify_on_exit!
  setup :set_mox_from_context
  
  setup %{authorized_conn: conn} do
    # Common mocks needed by all authorized tests
    stub(PrestoServiceMock, :is_select_statement?, fn _query -> true end)
    stub(PrestoServiceMock, :get_affected_tables, fn _arg1, _arg2 -> {:ok, []} end)
    stub(ModelMock, :get_all, fn -> [] end)
    :meck.expect(ModelAccessUtils, :has_access?, fn _arg1, _arg2 -> true end)
    
    if conn do
      # Manually set current_user for unit tests since Guardian middleware requires database
      current_user = %{id: @user_id}
      updated_conn = Plug.Conn.assign(conn, :current_user, current_user)
      [authorized_conn: updated_conn]
    else
      []
    end
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
      :meck.expect(Users, :get_user_with_organizations, fn ^subject, :subject_id -> {:ok, %{id: @user_id}} end)

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

      # Manually assign current_user for this test
      conn = Plug.Conn.assign(conn, :current_user, %{id: @user_id})

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