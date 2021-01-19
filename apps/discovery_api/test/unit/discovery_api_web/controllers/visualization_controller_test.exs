defmodule DiscoveryApiWeb.VisualizationControllerTest do
  use DiscoveryApiWeb.Test.AuthConnCase.UnitCase
  use Placebo

  alias DiscoveryApi.Schemas.Users
  alias DiscoveryApi.Schemas.Visualizations
  alias DiscoveryApi.Schemas.Visualizations.Visualization
  alias DiscoveryApiWeb.Utilities.QueryAccessUtils

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

  describe "with Auth0 auth provider" do
    test "POST /visualization returns CREATED for valid bearer token and visualization setup", %{
      authorized_conn: conn,
      authorized_subject: subject
    } do
      allow(Users.get_user_with_organizations(subject, :subject_id), return: {:ok, %{id: @user_id}})
      allow(Visualizations.get_visualizations_by_owner_id(@user_id), return: [])

      allow(Visualizations.create_visualization(any()),
        return: {:ok, %Visualization{public_id: @id, query: @query, title: @title, owner_id: @user_id, chart: @encoded_chart}}
      )

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
      allow(Users.get_user_with_organizations(subject, :subject_id), return: {:ok, %{id: @user_id}})

      allow(Visualizations.get_visualization_by_id(@id),
        return: {:ok, %Visualization{public_id: @id, query: @query, title: @title, owner_id: @user_id, chart: @encoded_chart, id: 1}}
      )

      expect(Visualizations.delete_visualization(any()),
        return: {:ok, :does_not_matter}
      )

      conn
      |> put_req_header("content-type", "application/json")
      |> delete("/api/v1/visualization/#{@id}")
      |> response(204)
    end

    test "DELETE /visualization returns BAD REQUEST for valid bearer token and an unowned visualization id", %{
      authorized_conn: conn,
      authorized_subject: subject
    } do
      allow(Users.get_user_with_organizations(subject, :subject_id), return: {:ok, %{id: @user_id}})

      allow(Visualizations.get_visualization_by_id(@id),
        return: {:ok, %Visualization{public_id: @id, query: @query, title: @title, owner_id: "frank", chart: @encoded_chart, id: 1}}
      )

      refute_called(Visualizations.delete_visualization(any()))

      conn
      |> put_req_header("content-type", "application/json")
      |> delete("/api/v1/visualization/#{@id}")
      |> response(400)
    end

    test "DELETE /visualization returns BAD REQUEST for non existant visualization id", %{
      authorized_conn: conn,
      authorized_subject: subject
    } do
      allow(Users.get_user_with_organizations(subject, :subject_id), return: {:ok, %{id: @user_id}})

      allow(Visualizations.get_visualization_by_id(@id), return: {:error, :does_not_matter})

      refute_called(Visualizations.delete_visualization(any()))

      conn
      |> put_req_header("content-type", "application/json")
      |> delete("/api/v1/visualization/#{@id}")
      |> response(400)
    end

    test "GET /visualization/id returns OK for valid bearer token and id", %{
      authorized_conn: conn,
      authorized_subject: subject
    } do
      datasets = ["123"]
      allow(Users.get_user_with_organizations(subject, :subject_id), return: {:ok, %{id: @user_id}})

      allow(Visualizations.get_visualization_by_id(@id),
        return:
          {:ok,
           %Visualization{public_id: @id, query: @query, title: @title, owner_id: "irrelevant", chart: @encoded_chart, datasets: datasets}}
      )

      allow(QueryAccessUtils.authorized_statement_models(@query), return: {:ok, nil, nil})
      allow(QueryAccessUtils.authorized_to_query?(any(), any(), any()), return: true)

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
      allow(Users.get_user_with_organizations(subject, :subject_id), return: {:ok, %{id: @user_id}})

      allow(Visualizations.get_visualization_by_id(@id),
        return: {:ok, %Visualization{public_id: @id, query: @query, title: @title, owner_id: @user_id, chart: @encoded_chart}}
      )

      allow(QueryAccessUtils.authorized_statement_models(@query), return: {:ok, nil, nil})
      allow(QueryAccessUtils.authorized_to_query?(any(), any(), any()), return: true)

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
      allow(Users.get_user_with_organizations(subject, :subject_id), return: {:ok, %{id: @user_id}})

      allow(Visualizations.get_visualization_by_id(@id),
        return: {:ok, %Visualization{public_id: @id, query: @query, title: @title, owner_id: "someone else", chart: @encoded_chart}}
      )

      allow(QueryAccessUtils.authorized_statement_models(@query), return: {:ok, nil, nil})
      allow(QueryAccessUtils.authorized_to_query?(any(), any(), any()), return: true)

      body =
        conn
        |> get("/api/v1/visualization/#{@id}")
        |> json_response(200)

      assert %{"allowedActions" => [%{"name" => "create_copy"}]} = body
    end

    test "GET /visualization/id returns no allowed actions when no user is signed in", %{
      anonymous_conn: conn
    } do
      allow(Visualizations.get_visualization_by_id(@id),
        return: {:ok, %Visualization{public_id: @id, query: @query, title: @title, owner_id: "someone else", chart: @encoded_chart}}
      )

      allow(QueryAccessUtils.authorized_statement_models(@query), return: {:ok, nil, nil})
      allow(QueryAccessUtils.authorized_to_query?(any(), any(), any()), return: true)

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
      allow(Users.get_user_with_organizations(subject, :subject_id), return: {:ok, %{id: @user_id}})

      allow(Visualizations.get_visualization_by_id(@id),
        return: {:ok, %Visualization{public_id: @id, query: @query, title: @title, owner_id: "irrelevant", chart: undecodable_chart}}
      )

      allow(QueryAccessUtils.authorized_statement_models(@query), return: {:ok, nil, nil})
      allow(QueryAccessUtils.authorized_to_query?(any(), any(), any()), return: true)

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
      allow(Users.get_user_with_organizations(subject, :subject_id), return: {:ok, %{id: @user_id}})

      allow(Visualizations.get_visualization_by_id(@id),
        return: {:ok, %Visualization{public_id: @id, query: @query, title: @title, owner_id: "irrelevant", chart: nil}}
      )

      allow(QueryAccessUtils.authorized_statement_models(@query), return: {:ok, nil, nil})
      allow(QueryAccessUtils.authorized_to_query?(any(), any(), any()), return: true)

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
      allow(Users.get_user_with_organizations(subject, :subject_id), return: {:ok, %{id: @user_id}})

      allow(Visualizations.get_visualizations_by_owner_id(@user_id),
        return: [
          %Visualization{public_id: "1", query: "blah", title: "blah blah", owner_id: @user_id, chart: "{}"},
          %Visualization{public_id: "2", query: "blah", title: "blah blah", owner_id: @user_id, chart: "{}"}
        ]
      )

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
