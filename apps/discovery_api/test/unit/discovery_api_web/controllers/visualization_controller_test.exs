defmodule DiscoveryApiWeb.VisualizationControllerTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo

  alias DiscoveryApi.Auth.GuardianConfigurator
  alias DiscoveryApi.Test.AuthHelper
  alias DiscoveryApi.Schemas.Users
  alias DiscoveryApi.Schemas.Users.User
  alias DiscoveryApi.Schemas.Visualizations
  alias DiscoveryApi.Schemas.Visualizations.Visualization
  alias DiscoveryApi.Auth.Auth0.CachedJWKS
  alias DiscoveryApiWeb.Utilities.QueryAccessUtils

  @user_id "asdfkjashdflkjhasdkjkadsf"

  @id "abcdefg"
  @title "My title"
  @query "select * from stuff"
  @decoded_chart %{"data" => [], "frames" => [], "layout" => %{}}
  @encoded_chart Jason.encode!(@decoded_chart)

  describe "with default auth provider" do
    setup do
      subject_id = "ringo"
      {:ok, token, _} = DiscoveryApi.Auth.Guardian.encode_and_sign(subject_id, %{}, token_type: "refresh")

      %{subject_id: subject_id, token: token}
    end

    test "POST /visualization returns CREATED for valid bearer token and visualization setup", %{
      conn: conn,
      subject_id: subject_id,
      token: token
    } do
      allow(Users.get_user_with_organizations(subject_id, :subject_id), return: {:ok, %{id: @user_id}})
      allow(Visualizations.get_visualizations_by_owner_id(@user_id), return: [])

      allow(Visualizations.create_visualization(any()),
        return: {:ok, %Visualization{public_id: @id, query: @query, title: @title, chart: @encoded_chart}}
      )

      body =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/visualization", ~s({"query": "#{@query}", "title": "#{@title}", "chart": #{@encoded_chart}}))
        |> response(201)
        |> Jason.decode!()

      assert %{
               "query" => @query,
               "title" => @title,
               "id" => @id,
               "chart" => @decoded_chart
             } = body
    end

    @moduletag capture_log: true
    test "POST /visualization returns UNAUTHORIZED for valid bearer token but missing user for visualization setup", %{
      conn: conn,
      subject_id: subject_id,
      token: token
    } do
      allow(Users.get_user_with_organizations(subject_id, :subject_id), return: {:error, :not_found})
      allow(Visualizations.get_visualizations_by_owner_id(@user_id), return: [])

      conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> put_req_header("content-type", "application/json")
      |> post("/api/v1/visualization", ~s({"query": "#{@query}", "title": "#{@title}", "chart": #{@encoded_chart}}))
      |> response(401)
    end

    test "POST /visualization returns BAD REQUEST when user creates more than the limit of visualizations for their account", %{
      conn: conn,
      subject_id: subject_id,
      token: token
    } do
      allow(Users.get_user_with_organizations(subject_id, :subject_id), return: {:ok, %{id: @user_id}})
      allow(Visualizations.get_visualizations_by_owner_id(@user_id), return: [1, 2, 3, 4, 5])

      allow(Visualizations.create_visualization(any()),
        return: {:ok, %Visualization{public_id: @id, query: @query, title: @title, chart: @encoded_chart}}
      )

      conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> put_req_header("content-type", "application/json")
      |> post("/api/v1/visualization", ~s({"query": "#{@query}", "title": "#{@title}", "chart": #{@encoded_chart}}))
      |> response(400)
    end

    test "PUT /visualization/id update visualization for existing id returns accepted", %{
      conn: conn,
      subject_id: subject_id,
      token: token
    } do
      user = %{id: @user_id}
      allow(Users.get_user_with_organizations(subject_id, :subject_id), return: {:ok, user})

      allow(Visualizations.update_visualization_by_id(@id, any(), user),
        return: {:ok, %Visualization{public_id: @id, query: @query, title: @title, owner_id: @user_id, chart: @encoded_chart}}
      )

      body =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("content-type", "application/json")
        |> put("/api/v1/visualization/#{@id}", %{"query" => @query, "title" => @title, "public_id" => @id, "chart" => @encoded_chart})
        |> response(200)
        |> Jason.decode!()

      assert %{
               "query" => @query,
               "title" => @title,
               "id" => @id,
               "chart" => @decoded_chart,
               "allowedActions" => [%{"name" => "update"}, %{"name" => "create_copy"}]
             } = body
    end

    test "GET /visualization/id returns OK for valid bearer token and id", %{subject_id: subject_id, token: token} do
      allow(Users.get_user_with_organizations(subject_id, :subject_id), return: {:ok, %{id: @user_id}})

      allow(Visualizations.get_visualization_by_id(@id),
        return: {:ok, %Visualization{public_id: @id, query: @query, title: @title, chart: @encoded_chart, owner_id: "irrelevant"}}
      )

      allow(DiscoveryApiWeb.Utilities.QueryAccessUtils.authorized_to_query?(@query, any()), return: true)

      body = get_visualization_body_with_code(token, 200)

      assert %{
               "query" => @query,
               "title" => @title,
               "id" => @id,
               "chart" => @decoded_chart
             } = body
    end

    test "GET /visualization/id returns NOT FOUND when visualization cannot be executed by the user", %{
      subject_id: subject_id,
      token: token
    } do
      user = %User{id: @user_id}
      allow(Users.get_user_with_organizations(subject_id, :subject_id), return: {:ok, user})
      private_system_name = "private__dataset"
      query = "select * from #{private_system_name}"

      private_dataset =
        DiscoveryApi.Test.Helper.sample_model(%{
          private: true,
          systemName: private_system_name
        })

      allow(DiscoveryApi.Data.Model.get_all(), return: [private_dataset], meck_options: [:passthrough])

      allow(Visualizations.get_visualization_by_id(@id),
        return: {:ok, %Visualization{public_id: @id, query: query, title: @title, chart: @encoded_chart, owner_id: "irrelevant"}}
      )

      allow(QueryAccessUtils.authorized_to_query?(query, user), return: false)

      body = get_visualization_body_with_code(token, 404)

      assert %{"message" => "Not Found"} == body
    end

    test "GET /visualization/id returns NOT FOUND when visualization cannot be fetched", %{subject_id: subject_id, token: token} do
      allow(Users.get_user_with_organizations(subject_id, :subject_id), return: {:ok, %{id: @user_id}})
      allow(Visualizations.get_visualization_by_id(@id), return: {:error, "no such visualization"})

      body = get_visualization_body_with_code(token, 404)

      assert %{"message" => "Not Found"} == body
    end

    test "GET /visualization/id returns visualization when user is owner regardless of query contents", %{
      subject_id: subject_id,
      token: token
    } do
      allow(Users.get_user_with_organizations(subject_id, :subject_id), return: {:ok, %{id: @user_id}})
      query = "select * from garbage"

      allow(Visualizations.get_visualization_by_id(@id),
        return: {:ok, %Visualization{public_id: @id, query: query, title: @title, chart: @encoded_chart, owner_id: @user_id}}
      )

      body = get_visualization_body_with_code(token, 200)

      assert %{
               "query" => ^query,
               "title" => @title,
               "id" => @id,
               "chart" => @decoded_chart
             } = body
    end

    test "GET /visualization gets all visualizations for user with valid bearer token", %{subject_id: subject_id, token: token} do
      allow(Users.get_user_with_organizations(subject_id, :subject_id), return: {:ok, %{id: @user_id}})

      allow(Visualizations.get_visualizations_by_owner_id(@user_id),
        return: [
          %Visualization{public_id: "1", query: "blah", title: "blah blah", owner_id: @user_id, chart: "{}"},
          %Visualization{public_id: "2", query: "blah", title: "blah blah", owner_id: @user_id, chart: "{}"}
        ]
      )

      body =
        build_conn()
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("content-type", "application/json")
        |> get("/api/v1/visualization")
        |> response(200)
        |> Jason.decode!()

      assert [%{"id" => "1"}, %{"id" => "2"}] = body
    end

    test "GET /visualization returns UNAUTHENTICATED with no user signed in" do
      build_conn()
      |> put_req_header("content-type", "application/json")
      |> get("/api/v1/visualization")
      |> response(401)
    end
  end

  describe "with Auth0 auth provider" do
    setup do
      secret_key = Application.get_env(:discovery_api, DiscoveryApi.Auth.Guardian) |> Keyword.get(:secret_key)
      GuardianConfigurator.configure("auth0", issuer: AuthHelper.valid_issuer())

      jwks = AuthHelper.valid_jwks()
      CachedJWKS.set(jwks)

      bypass = Bypass.open()

      really_far_in_the_future = 3_000_000_000_000
      AuthHelper.set_allowed_guardian_drift(really_far_in_the_future)

      Application.put_env(
        :discovery_api,
        :user_info_endpoint,
        "http://localhost:#{bypass.port}/userinfo"
      )

      Bypass.stub(bypass, "GET", "/userinfo", fn conn ->
        Plug.Conn.resp(conn, :ok, Jason.encode!(%{"email" => "x@y.z"}))
      end)

      on_exit(fn ->
        AuthHelper.set_allowed_guardian_drift(0)
        GuardianConfigurator.configure("default", secret_key: secret_key)
      end)

      %{subject_id: AuthHelper.valid_jwt_sub(), token: AuthHelper.valid_jwt()}
    end

    test "POST /visualization returns CREATED for valid bearer token and visualization setup", %{
      conn: conn,
      subject_id: subject_id,
      token: token
    } do
      allow(Users.get_user_with_organizations(subject_id, :subject_id), return: {:ok, %{id: @user_id}})
      allow(Visualizations.get_visualizations_by_owner_id(@user_id), return: [])

      allow(Visualizations.create_visualization(any()),
        return: {:ok, %Visualization{public_id: @id, query: @query, title: @title, owner_id: @user_id, chart: @encoded_chart}}
      )

      body =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
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

    test "GET /visualization/id returns OK for valid bearer token and id", %{subject_id: subject_id, token: token} do
      allow(Users.get_user_with_organizations(subject_id, :subject_id), return: {:ok, %{id: @user_id}})

      allow(Visualizations.get_visualization_by_id(@id),
        return: {:ok, %Visualization{public_id: @id, query: @query, title: @title, owner_id: "irrelevant", chart: @encoded_chart}}
      )

      allow(QueryAccessUtils.authorized_to_query?(@query, any()), return: true)

      body = get_visualization_body_with_code(token, 200)

      assert %{
               "query" => @query,
               "title" => @title,
               "id" => @id,
               "chart" => @decoded_chart
             } = body
    end

    test "GET /visualization/id returns update and create_copy actions when user is owner", %{subject_id: subject_id, token: token} do
      allow(Users.get_user_with_organizations(subject_id, :subject_id), return: {:ok, %{id: @user_id}})

      allow(Visualizations.get_visualization_by_id(@id),
        return: {:ok, %Visualization{public_id: @id, query: @query, title: @title, owner_id: @user_id, chart: @encoded_chart}}
      )

      allow(QueryAccessUtils.authorized_to_query?(@query, any()), return: true)

      body = get_visualization_body_with_code(token, 200)

      assert %{"allowedActions" => [%{"name" => "update"}, %{"name" => "create_copy"}]} = body
    end

    test "GET /visualization/id returns only create_copy action when user is not the owner", %{subject_id: subject_id, token: token} do
      allow(Users.get_user_with_organizations(subject_id, :subject_id), return: {:ok, %{id: @user_id}})

      allow(Visualizations.get_visualization_by_id(@id),
        return: {:ok, %Visualization{public_id: @id, query: @query, title: @title, owner_id: "someone else", chart: @encoded_chart}}
      )

      allow(QueryAccessUtils.authorized_to_query?(@query, any()), return: true)

      body = get_visualization_body_with_code(token, 200)

      assert %{"allowedActions" => [%{"name" => "create_copy"}]} = body
    end

    test "GET /visualization/id returns no allowed actions when no user is signed in" do
      allow(Visualizations.get_visualization_by_id(@id),
        return: {:ok, %Visualization{public_id: @id, query: @query, title: @title, owner_id: "someone else", chart: @encoded_chart}}
      )

      allow(QueryAccessUtils.authorized_to_query?(@query, any()), return: true)

      body =
        build_conn()
        |> put_req_header("content-type", "application/json")
        |> get("/api/v1/visualization/#{@id}")
        |> response(200)
        |> Jason.decode!()

      assert %{"allowedActions" => []} = body
    end

    test "GET /visualization/id returns OK but empty chart if it is not decodable", %{subject_id: subject_id, token: token} do
      undecodable_chart = ~s({"data": ]]})
      allow(Users.get_user_with_organizations(subject_id, :subject_id), return: {:ok, %{id: @user_id}})

      allow(Visualizations.get_visualization_by_id(@id),
        return: {:ok, %Visualization{public_id: @id, query: @query, title: @title, owner_id: "irrelevant", chart: undecodable_chart}}
      )

      allow(QueryAccessUtils.authorized_to_query?(@query, any()), return: true)

      body = get_visualization_body_with_code(token, 200)

      assert %{
               "query" => @query,
               "title" => @title,
               "id" => @id,
               "chart" => %{}
             } = body
    end

    test "GET /visualization/id returns OK but empty chart when chart is nil", %{subject_id: subject_id, token: token} do
      allow(Users.get_user_with_organizations(subject_id, :subject_id), return: {:ok, %{id: @user_id}})

      allow(Visualizations.get_visualization_by_id(@id),
        return: {:ok, %Visualization{public_id: @id, query: @query, title: @title, owner_id: "irrelevant", chart: nil}}
      )

      allow(QueryAccessUtils.authorized_to_query?(@query, any()), return: true)

      body = get_visualization_body_with_code(token, 200)

      assert %{
               "query" => @query,
               "title" => @title,
               "id" => @id,
               "chart" => %{}
             } = body
    end

    test "GET /visualization gets all visualizations for user with valid bearer token", %{subject_id: subject_id, token: token} do
      allow(Users.get_user_with_organizations(subject_id, :subject_id), return: {:ok, %{id: @user_id}})

      allow(Visualizations.get_visualizations_by_owner_id(@user_id),
        return: [
          %Visualization{public_id: "1", query: "blah", title: "blah blah", owner_id: @user_id, chart: "{}"},
          %Visualization{public_id: "2", query: "blah", title: "blah blah", owner_id: @user_id, chart: "{}"}
        ]
      )

      body =
        build_conn()
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("content-type", "application/json")
        |> get("/api/v1/visualization")
        |> response(200)
        |> Jason.decode!()

      assert [
               %{"id" => "1", "allowedActions" => [%{"name" => "update"}, %{"name" => "create_copy"}]},
               %{"id" => "2", "allowedActions" => [%{"name" => "update"}, %{"name" => "create_copy"}]}
             ] = body
    end

    test "GET /visualization returns UNAUTHENTICATED with no user signed in" do
      build_conn()
      |> put_req_header("content-type", "application/json")
      |> get("/api/v1/visualization")
      |> response(401)
    end
  end

  defp get_visualization_body_with_code(token, code) do
    build_conn()
    |> put_req_header("authorization", "Bearer #{token}")
    |> put_req_header("content-type", "application/json")
    |> get("/api/v1/visualization/#{@id}")
    |> response(code)
    |> Jason.decode!()
  end
end
