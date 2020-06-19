defmodule DiscoveryApiWeb.VisualizationControllerTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo

  alias DiscoveryApi.Test.AuthHelper
  alias DiscoveryApi.Schemas.Users
  alias DiscoveryApi.Schemas.Visualizations
  alias DiscoveryApi.Schemas.Visualizations.Visualization
  alias DiscoveryApi.Auth.GuardianConfigurator
  alias DiscoveryApi.Auth.Auth0.CachedJWKS
  alias DiscoveryApiWeb.Auth.TokenHandler
  alias DiscoveryApiWeb.Utilities.QueryAccessUtils

  @user_id "asdfkjashdflkjhasdkjkadsf"

  @id "abcdefg"
  @title "My title"
  @query "select * from stuff"
  @decoded_chart %{"data" => [], "frames" => [], "layout" => %{}}
  @encoded_chart Jason.encode!(@decoded_chart)

  describe "with Auth0 auth provider" do
    setup do
      secret_key = Application.get_env(:discovery_api, TokenHandler) |> Keyword.get(:secret_key)
      GuardianConfigurator.configure(issuer: AuthHelper.valid_issuer())

      jwks = AuthHelper.valid_jwks()
      CachedJWKS.set(jwks)
      allow(TokenHandler.on_verify(any(), any(), any()), exec: &AuthHelper.guardian_verify_passthrough/3, meck_options: [:passthrough])

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
        GuardianConfigurator.configure(secret_key: secret_key)
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

    test "DELETE /visualization returns NO CONTENT for valid bearer token and an owned visualization id", %{
      conn: conn,
      subject_id: subject_id,
      token: token
    } do
      allow(Users.get_user_with_organizations(subject_id, :subject_id), return: {:ok, %{id: @user_id}})

      allow(Visualizations.get_visualization_by_id(@id),
        return: {:ok, %Visualization{public_id: @id, query: @query, title: @title, owner_id: @user_id, chart: @encoded_chart, id: 1}}
      )

      expect(Visualizations.delete_visualization(1),
        return: {:ok, :does_not_matter}
      )

      conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> put_req_header("content-type", "application/json")
      |> delete("/api/v1/visualization/#{@id}")
      |> response(204)
    end

    test "DELETE /visualization returns BAD REQUEST for valid bearer token and an unowned visualization id", %{
      conn: conn,
      subject_id: subject_id,
      token: token
    } do
      allow(Users.get_user_with_organizations(subject_id, :subject_id), return: {:ok, %{id: @user_id}})

      allow(Visualizations.get_visualization_by_id(@id),
        return: {:ok, %Visualization{public_id: @id, query: @query, title: @title, owner_id: "frank", chart: @encoded_chart, id: 1}}
      )

      refute_called(Visualizations.delete_visualization(1))

      conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> put_req_header("content-type", "application/json")
      |> delete("/api/v1/visualization/#{@id}")
      |> response(400)
    end

    test "DELETE /visualization returns BAD REQUEST for non existant visualization id", %{
      conn: conn,
      subject_id: subject_id,
      token: token
    } do
      allow(Users.get_user_with_organizations(subject_id, :subject_id), return: {:ok, %{id: @user_id}})

      allow(Visualizations.get_visualization_by_id(@id), return: {:error, :does_not_matter})

      refute_called(Visualizations.delete_visualization(any()))

      conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> put_req_header("content-type", "application/json")
      |> delete("/api/v1/visualization/#{@id}")
      |> response(400)
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
