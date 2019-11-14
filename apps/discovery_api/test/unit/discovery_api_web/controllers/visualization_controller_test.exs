defmodule DiscoveryApiWeb.VisualizationControllerTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo

  alias DiscoveryApi.Test.AuthHelper
  alias DiscoveryApi.Schemas.Users
  alias DiscoveryApi.Schemas.Visualizations
  alias DiscoveryApi.Schemas.Visualizations.Visualization
  alias DiscoveryApi.Auth.Auth0.CachedJWKS

  @valid_jwt AuthHelper.valid_jwt()
  @valid_jwt_subject AuthHelper.valid_jwt_sub()
  @user_info_body Jason.encode!(%{"email" => "x@y.z"})

  @user_id "asdfkjashdflkjhasdkjkadsf"

  @id "abcdefg"
  @title "My title"
  @query "select * from stuff"

  setup do
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
      Plug.Conn.resp(conn, :ok, @user_info_body)
    end)

    :ok
  end

  describe "POST /visualization" do
    test "returns CREATED for valid bearer token and visualization setup", %{conn: conn} do
      allow(Users.get_user(@valid_jwt_subject, :subject_id), return: {:ok, %{id: @user_id}})

      allow(Visualizations.create_visualization(any()),
        return: {:ok, %Visualization{public_id: @id, query: @query, title: @title}}
      )

      body =
        conn
        |> put_req_header("authorization", "Bearer #{@valid_jwt}")
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/visualization", ~s({"query": "#{@query}", "title": "#{@title}"}))
        |> response(201)
        |> Jason.decode!()

      assert %{
               "query" => @query,
               "title" => @title,
               "id" => @id
             } = body
    end

    test "returns BAD REQUEST for valid bearer token but missing user for visualization setup", %{
      conn: conn
    } do
      allow(Users.get_user(@valid_jwt_subject, :subject_id), return: {:error, :not_found})

      conn
      |> put_req_header("authorization", "Bearer #{@valid_jwt}")
      |> put_req_header("content-type", "application/json")
      |> post("/api/v1/visualization", ~s({"query": "#{@query}", "title": "#{@title}"}))
      |> response(400)
    end

    test "returns BAD REQUEST for valid bearer token and but missing user for visualization setup",
         %{conn: conn} do
      allow(Users.get_user(@valid_jwt_subject, :subject_id), return: {:error, :not_found})

      conn
      |> put_req_header("authorization", "Bearer #{@valid_jwt}")
      |> put_req_header("content-type", "application/json")
      |> post("/api/v1/visualization", ~s({"query": "#{@query}", "title": "#{@title}"}))
      |> response(400)
    end
  end

  describe "PUT /visualization/id" do
    setup do
      allow(Users.get_user(@valid_jwt_subject, :subject_id), return: {:ok, %{id: @user_id}})
      :ok
    end

    test "update visualization for existing id returns accepted", %{conn: conn} do
      allow(Visualizations.get_visualization_by_id(any()), return: {:ok, %Visualization{public_id: @id, query: @query, title: @title}})
      allow(Visualization.changeset(any(), any()), return: {:ok, %Visualization{public_id: @id, query: @query, title: @title}})

      allow(Visualizations.update_visualization_by_id(any(), any(), any()),
        return: {:ok, %Visualization{public_id: @id, query: @query, title: @title}}
      )

      body =
        conn
        |> put_req_header("authorization", "Bearer #{@valid_jwt}")
        |> put_req_header("content-type", "application/json")
        |> put("/api/v1/visualization/#{@id}", %{"query" => @query, "title" => @title, "public_id" => @id})
        |> response(200)
        |> Jason.decode!()

      assert %{
               "query" => @query,
               "title" => @title,
               "id" => @id
             } = body
    end
  end

  describe "GET /visualization" do
    setup do
      allow(Users.get_user(@valid_jwt_subject, :subject_id), return: {:ok, %{id: @user_id}})
      :ok
    end

    test "returns OK for valid bearer token and id" do
      allow(Visualizations.get_visualization_by_id(@id),
        return: {:ok, %Visualization{public_id: @id, query: @query, title: @title, owner_id: "irrelevant"}}
      )

      allow(DiscoveryApiWeb.Utilities.AuthUtils.authorized_to_query?(@query, any(), any()), return: true)

      body = get_visualization_body_with_code(200)

      assert %{
               "query" => @query,
               "title" => @title,
               "id" => @id
             } = body
    end

    test "returns NOT FOUND when visualization cannot be executed by the user" do
      private_system_name = "private__dataset"
      query = "select * from #{private_system_name}"

      private_dataset =
        DiscoveryApi.Test.Helper.sample_model(%{
          private: true,
          systemName: private_system_name
        })

      allow(DiscoveryApi.Data.Model.get_all(), return: [private_dataset], meck_options: [:passthrough])

      allow(Visualizations.get_visualization_by_id(@id),
        return: {:ok, %Visualization{public_id: @id, query: query, title: @title, owner_id: "irrelevant"}}
      )

      allow(DiscoveryApiWeb.Utilities.AuthUtils.authorized_to_query?(query, @valid_jwt_subject, any()), return: false)

      body = get_visualization_body_with_code(404)

      assert %{"message" => "Not Found"} == body
    end

    test "returns NOT FOUND when visualization cannot be fetched" do
      allow(Visualizations.get_visualization_by_id(@id), return: {:error, "no such visualization"})

      body = get_visualization_body_with_code(404)

      assert %{"message" => "Not Found"} == body
    end

    test "returns visualization when user is owner regardless of query contents" do
      query = "select * from garbage"

      allow(Visualizations.get_visualization_by_id(@id),
        return: {:ok, %Visualization{public_id: @id, query: query, title: @title, owner_id: @user_id}}
      )

      body = get_visualization_body_with_code(200)

      assert %{
               "query" => ^query,
               "title" => @title,
               "id" => @id
             } = body
    end
  end

  defp get_visualization_body_with_code(code) do
    build_conn()
    |> put_req_header("authorization", "Bearer #{@valid_jwt}")
    |> put_req_header("content-type", "application/json")
    |> get("/api/v1/visualization/#{@id}")
    |> response(code)
    |> Jason.decode!()
  end
end
