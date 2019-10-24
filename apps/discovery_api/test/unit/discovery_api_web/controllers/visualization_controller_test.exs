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

  setup do
    jwks = AuthHelper.valid_jwks()
    CachedJWKS.set(jwks)

    bypass = Bypass.open()

    really_far_in_the_future = 3_000_000_000_000
    AuthHelper.set_allowed_guardian_drift(really_far_in_the_future)
    Application.put_env(:discovery_api, :user_info_endpoint, "http://localhost:#{bypass.port}/userinfo")
    Bypass.stub(bypass, "GET", "/userinfo", fn conn -> Plug.Conn.resp(conn, :ok, @user_info_body) end)

    :ok
  end

  describe "POST /visualization" do
    test "returns CREATED for valid bearer token and visualization setup", %{conn: conn} do
      generated_public_id = "abcdefg"
      query = "select * from stuff"
      title = "My title"

      allow(Users.get_user(@valid_jwt_subject), return: {:ok, :valid_user})
      allow(Visualizations.create(any()), return: {:ok, %Visualization{public_id: generated_public_id, query: query, title: title}})

      body =
        conn
        |> put_req_header("authorization", "Bearer #{@valid_jwt}")
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/visualization", ~s({"query": "#{query}", "title": "#{title}"}))
        |> response(201)
        |> Jason.decode!()

      assert %{
               "query" => ^query,
               "title" => ^title,
               "id" => ^generated_public_id
             } = body
    end

    test "returns BAD REQUEST for valid bearer token but missing user for visualization setup", %{conn: conn} do
      query = "select * from stuff"
      title = "My title"

      allow(Users.get_user(@valid_jwt_subject), return: {:error, :not_found})

      conn
      |> put_req_header("authorization", "Bearer #{@valid_jwt}")
      |> put_req_header("content-type", "application/json")
      |> post("/api/v1/visualization", ~s({"query": "#{query}", "title": "#{title}"}))
      |> response(400)
    end

    test "returns BAD REQUEST for valid bearer token and but missing user for visualization setup", %{conn: conn} do
      query = "select * from stuff"
      title = "My title"

      allow(Users.get_user(@valid_jwt_subject), return: {:error, :not_found})

      conn
      |> put_req_header("authorization", "Bearer #{@valid_jwt}")
      |> put_req_header("content-type", "application/json")
      |> post("/api/v1/visualization", ~s({"query": "#{query}", "title": "#{title}"}))
      |> response(400)
    end
  end

  describe "PUT /visualization/id" do
    test "update visualization for existing id returns accepted", %{conn: conn} do
      id = "abcd1234"
      query = "select * from table"
      title = "query title"

      allow(Users.get_user(@valid_jwt_subject), return: {:ok, :valid_user})
      allow(Visualizations.get_visualization(any()), return: {:ok, %Visualization{public_id: id, query: query, title: title}})
      allow(Visualization.changeset(any(), any()), return: {:ok, %Visualization{public_id: id, query: query, title: title}})
      allow(Visualizations.update(any()), return: {:ok, %Visualization{public_id: id, query: query, title: title}})

      body =
        conn
        |> put_req_header("authorization", "Bearer #{@valid_jwt}")
        |> put_req_header("content-type", "application/json")
        |> put("/api/v1/visualization/#{id}", %{"id" => id, "query" => query, "title" => title})
        |> response(202)
        |> Jason.decode!()

      assert %{
               "query" => ^query,
               "title" => ^title,
               "id" => ^id
             } = body
    end
  end

  describe "GET /visualization" do
    test "returns OK for valid bearer token and id", %{conn: conn} do
      id = "abcdefg"
      query = "select * from stuff"
      title = "My title"

      allow(Users.get_user(@valid_jwt_subject), return: {:ok, :valid_user})
      allow(Visualizations.get_visualization(id), return: {:ok, %Visualization{public_id: id, query: query, title: title}})

      body =
        conn
        |> put_req_header("authorization", "Bearer #{@valid_jwt}")
        |> put_req_header("content-type", "application/json")
        |> get("/api/v1/visualization/#{id}")
        |> response(200)
        |> Jason.decode!()

      assert %{
               "query" => ^query,
               "title" => ^title,
               "id" => ^id
             } = body
    end

    test "returns NOT FOUND when visualization cannot be fetched", %{conn: conn} do
      id = "abcdefg"

      allow(Users.get_user(@valid_jwt_subject), return: {:ok, :valid_user})
      allow(Visualizations.get_visualization(id), return: {:error, "no such visualization"})

      body =
        conn
        |> put_req_header("authorization", "Bearer #{@valid_jwt}")
        |> put_req_header("content-type", "application/json")
        |> get("/api/v1/visualization/#{id}")
        |> response(404)
        |> Jason.decode!()

      assert %{"message" => "Not Found"} == body
    end
  end
end
