defmodule DiscoveryApi.Auth.AuthTest do
  use ExUnit.Case
  use Divo, services: [:"ecto-postgres", :redis, :presto, :zookeeper, :kafka]
  use DiscoveryApi.DataCase

  import ExUnit.CaptureLog
  import SmartCity.TestHelper, only: [eventually: 3]

  alias DiscoveryApi.Auth.GuardianConfigurator
  alias DiscoveryApiWeb.Auth.TokenHandler
  alias DiscoveryApi.Test.Helper
  alias DiscoveryApi.Test.AuthHelper
  alias DiscoveryApi.Schemas.Users
  alias DiscoveryApi.Schemas.Visualizations
  alias DiscoveryApi.Repo

  @organization_1_name "organization_one"
  @organization_2_name "organization_two"

  setup_all do
    Helper.wait_for_brook_to_be_ready()

    organization_1 = Helper.create_persisted_organization(%{orgName: @organization_1_name})
    organization_2 = Helper.create_persisted_organization(%{orgName: @organization_2_name})

    private_model_that_belongs_to_org_1 =
      Helper.sample_model(%{
        private: true,
        organization: @organization_1_name,
        organizationDetails: organization_1,
        keywords: ["dataset", "facet1"]
      })

    private_model_that_belongs_to_org_2 =
      Helper.sample_model(%{
        private: true,
        organization: @organization_2_name,
        organizationDetails: organization_2,
        keywords: ["dataset", "facet2"]
      })

    public_model_that_belongs_to_org_1 =
      Helper.sample_model(%{
        private: false,
        organization: @organization_1_name,
        organizationDetails: organization_1,
        keywords: ["dataset", "public_facet"]
      })

    Helper.clear_saved_models()
    Helper.save_model(private_model_that_belongs_to_org_1)
    Helper.save_model(private_model_that_belongs_to_org_2)
    Helper.save_model(public_model_that_belongs_to_org_1)

    {:ok,
     %{
       private_model_that_belongs_to_org_1: private_model_that_belongs_to_org_1,
       private_model_that_belongs_to_org_2: private_model_that_belongs_to_org_2,
       public_model_that_belongs_to_org_1: public_model_that_belongs_to_org_1
     }}
  end

  describe "GET /dataset/:dataset_id with auth0 auth provider" do
    setup %{private_model_that_belongs_to_org_1: model} do
      auth0_setup()
      |> on_exit()

      {user, token, _} = AuthHelper.login()
      Helper.associate_user_with_organization(user.id, model.organizationDetails.id)

      [user_token: token]
    end

    @moduletag capture_log: true
    test "is able to access a restricted dataset with a valid token", setup_map do
      %{status_code: status_code, body: body} =
        get_with_authentication(
          "http://localhost:4000/api/v1/dataset/#{setup_map[:private_model_that_belongs_to_org_1].id}/",
          setup_map.user_token
        )

      assert 200 == status_code
      assert body.id == setup_map[:private_model_that_belongs_to_org_1].id
    end

    @moduletag capture_log: true
    test "is not able to access a restricted dataset with a bad token", setup_map do
      %{status_code: status_code, body: body} =
        get_with_authentication(
          "http://localhost:4000/api/v1/dataset/#{setup_map[:private_model_that_belongs_to_org_1].id}/",
          "sdfsadfasdasdfas"
        )

      assert status_code == 401
      assert body.message == "Unauthorized"
    end
  end

  describe "/api/v1/search with auth0 auth provider" do
    setup %{private_model_that_belongs_to_org_1: model} do
      auth0_setup()
      |> on_exit()

      {user, token, _} = AuthHelper.login()
      Helper.associate_user_with_organization(user.id, model.organizationDetails.id)

      [user_token: token]
    end

    test "filters all private datasets when no auth token provided", setup_map do
      %{body: body} = HTTPoison.get!("http://localhost:4000/api/v1/dataset/search/")

      %{results: results} = Jason.decode!(body, keys: :atoms)
      result_ids = Enum.map(results, fn result -> result[:id] end)

      assert setup_map[:public_model_that_belongs_to_org_1].id in result_ids
      assert setup_map[:private_model_that_belongs_to_org_1].id not in result_ids
      assert setup_map[:private_model_that_belongs_to_org_2].id not in result_ids
    end

    test "allows access to private datasets when auth token provided and is permitted", setup_map do
      %{body: %{results: results}} =
        get_with_authentication(
          "http://localhost:4000/api/v1/dataset/search/",
          setup_map.user_token
        )

      result_ids = Enum.map(results, fn result -> result[:id] end)
      assert setup_map[:private_model_that_belongs_to_org_1].id in result_ids
      assert setup_map[:public_model_that_belongs_to_org_1].id in result_ids
      assert setup_map[:private_model_that_belongs_to_org_2].id not in result_ids
    end
  end

  describe "POST /logged-in" do
    setup do
      auth0_setup()
      |> on_exit()
    end

    test "returns 'OK' when token is valid" do
      %{status_code: status_code} =
        "localhost:4000/api/v1/logged-in"
        |> HTTPoison.post!("",
          Authorization: "Bearer #{AuthHelper.valid_jwt()}"
        )

      assert status_code == 200
    end

    test "login is IDEMpotent" do
      assert %{status_code: 200} =
               HTTPoison.post!(
                 "localhost:4000/api/v1/logged-in",
                 "",
                 Authorization: "Bearer #{AuthHelper.valid_jwt()}"
               )

      assert %{status_code: 200} =
               HTTPoison.post!(
                 "localhost:4000/api/v1/logged-in",
                 "",
                 Authorization: "Bearer #{AuthHelper.valid_jwt()}"
               )
    end

    test "saves logged in user" do
      subject_id = AuthHelper.valid_jwt_sub()

      eventually(
        fn ->
          assert {:ok, _} =
                   HTTPoison.post(
                     "localhost:4000/api/v1/logged-in",
                     "",
                     Authorization: "Bearer #{AuthHelper.valid_jwt()}"
                   )

          assert {:ok, actual} = Users.get_user(subject_id, :subject_id)

          assert subject_id == actual.subject_id
          assert "x@y.z" == actual.email
          assert actual.id != nil
        end,
        2000,
        10
      )
    end

    test "returns 'unauthorized' when token is invalid" do
      %{status_code: status_code} =
        "localhost:4000/api/v1/logged-in"
        |> HTTPoison.post!(
          "",
          Authorization: "Bearer !NOPE!"
        )

      assert status_code == 401
    end
  end

  describe "POST /logged-out" do
    setup do
      auth0_setup()
      |> on_exit()
    end

    test "when user is logged-out, they can't re-add their token via logged-in" do
      subject = AuthHelper.revocable_jwt_sub()

      {_, token, 200} = AuthHelper.login(subject, AuthHelper.revocable_jwt())

      assert %{status_code: 200} =
               "localhost:4000/api/v1/logged-out"
               |> HTTPoison.post!(
                 "",
                 Authorization: "Bearer " <> token
               )

      assert {_, _, 401} = AuthHelper.login(subject, token)
    end

    test "logout is not idempotent" do
      subject = AuthHelper.revocable_jwt_sub()

      {_, token, 200} = AuthHelper.login(subject, AuthHelper.revocable_jwt())

      assert %{status_code: 200} =
               "localhost:4000/api/v1/logged-out"
               |> HTTPoison.post!(
                 "",
                 Authorization: "Bearer " <> token
               )

      assert %{status_code: 401} =
               "localhost:4000/api/v1/logged-out"
               |> HTTPoison.post!(
                 "",
                 Authorization: "Bearer " <> token
               )

      assert {_, _, 401} = AuthHelper.login(subject, token)
    end

    test "when user is logged-out, they can't use their token to access protected resources, even when they attempt to re-add their token",
         %{private_model_that_belongs_to_org_1: model} do
      subject = AuthHelper.revocable_jwt_sub()
      model_id = model.id

      {user, token, 200} = AuthHelper.login(subject, AuthHelper.revocable_jwt())

      Helper.associate_user_with_organization(
        user.id,
        model.organizationDetails.id
      )

      assert %{status_code: 200, body: %{id: ^model_id}} =
               get_with_authentication(
                 "http://localhost:4000/api/v1/dataset/#{model.id}/",
                 token
               )

      assert %{status_code: 200} =
               HTTPoison.post!(
                 "localhost:4000/api/v1/logged-out",
                 "",
                 Authorization: "Bearer " <> token
               )

      assert %{status_code: 401, body: %{message: "Unauthorized"}} =
               get_with_authentication(
                 "http://localhost:4000/api/v1/dataset/#{model.id}/",
                 token
               )

      assert {_, _, 401} = AuthHelper.login(subject, token)

      assert %{status_code: 401, body: %{message: "Unauthorized"}} =
               get_with_authentication(
                 "http://localhost:4000/api/v1/dataset/#{model.id}/",
                 token
               )
    end

    test "when user is logged-out, it doesn't affect other users", %{private_model_that_belongs_to_org_1: model} do
      subject = AuthHelper.revocable_jwt_sub()
      other_subject = AuthHelper.valid_jwt_sub()
      model_id = model.id

      {user, token, 200} = AuthHelper.login(subject, AuthHelper.revocable_jwt())

      Helper.associate_user_with_organization(
        user.id,
        model.organizationDetails.id
      )

      {user, other_token, 200} = AuthHelper.login(other_subject, AuthHelper.valid_jwt())

      Helper.associate_user_with_organization(
        user.id,
        model.organizationDetails.id
      )

      assert %{status_code: 200} =
               HTTPoison.post!(
                 "localhost:4000/api/v1/logged-out",
                 "",
                 Authorization: "Bearer " <> token
               )

      assert %{status_code: 401, body: %{message: "Unauthorized"}} =
               get_with_authentication(
                 "http://localhost:4000/api/v1/dataset/#{model.id}/",
                 token
               )

      assert %{status_code: 200, body: %{id: ^model_id}} =
               get_with_authentication(
                 "http://localhost:4000/api/v1/dataset/#{model.id}/",
                 other_token
               )
    end
  end

  describe "POST /visualization" do
    setup do
      auth0_setup()
      |> on_exit()
    end

    test "adds owner data to the newly created visualization" do
      {user, token, _} = AuthHelper.login()

      %{status_code: status_code, body: body} =
        post_with_authentication(
          "localhost:4000/api/v1/visualization",
          ~s({"query": "select * from tarps", "title": "My favorite title", "chart": {"data": "hello"}}),
          token
        )

      assert status_code == 201

      visualization = Visualizations.get_visualization_by_id(body.id) |> elem(1) |> Repo.preload(:owner)

      assert visualization.owner.subject_id == user.subject_id
    end

    test "returns 'unauthorized' when token is invalid" do
      %{status_code: status_code, body: body} =
        post_with_authentication(
          "localhost:4000/api/v1/visualization",
          ~s({"query": "select * from tarps", "title": "My favorite title"}),
          "!WRONG!"
        )

      assert status_code == 401
      assert body.message == "Unauthorized"
    end
  end

  describe "GET /visualization/:id" do
    setup do
      auth0_setup()
      |> on_exit()
    end

    test "returns visualization for public table when user is anonymous",
         %{
           public_model_that_belongs_to_org_1: model
         } do
      capture_log(fn ->
        DiscoveryApi.prestige_opts()
        |> Prestige.new_session()
        |> Prestige.query(~s|create table if not exists "#{model.systemName}" (id integer, name varchar)|)
      end)

      visualization = create_visualization(model.systemName)

      %{status_code: status_code} =
        HTTPoison.get!(
          "localhost:4000/api/v1/visualization/#{visualization.public_id}",
          "Content-Type": "application/json"
        )

      assert status_code == 200
    end

    test "returns visualization for private table when user has access", %{
      private_model_that_belongs_to_org_1: model
    } do
      {user, token, _} = AuthHelper.login()
      Helper.associate_user_with_organization(user.id, model.organizationDetails.id)

      capture_log(fn ->
        DiscoveryApi.prestige_opts()
        |> Prestige.new_session()
        |> Prestige.query(~s|create table if not exists "#{model.systemName}" (id integer, name varchar)|)
      end)

      visualization = create_visualization(model.systemName)

      %{status_code: status_code} =
        get_with_authentication(
          "localhost:4000/api/v1/visualization/#{visualization.public_id}",
          token
        )

      assert status_code == 200
    end

    test "returns not found for private table when user is anonymous", %{
      private_model_that_belongs_to_org_1: model
    } do
      capture_log(fn ->
        DiscoveryApi.prestige_opts()
        |> Prestige.new_session()
        |> Prestige.query(~s|create table if not exists "#{model.systemName}" (id integer, name varchar)|)
      end)

      DiscoveryApi.prestige_opts() |> Prestige.new_session() |> Prestige.query!("describe #{model.systemName}") |> Prestige.Result.as_maps()

      visualization = create_visualization(model.systemName)

      %{status_code: status_code} =
        HTTPoison.get!(
          "localhost:4000/api/v1/visualization/#{visualization.public_id}",
          "Content-Type": "application/json"
        )

      assert status_code == 404
    end
  end

  defp create_visualization(table_name) do
    owner = Helper.create_persisted_user("me|you")

    {:ok, visualization} =
      Visualizations.create_visualization(%{
        query: "select * from #{table_name}",
        title: "My first visualization",
        owner: owner
      })

    visualization
  end

  defp post_with_authentication(url, body, bearer_token) do
    %{
      status_code: status_code,
      body: body_json
    } =
      HTTPoison.post!(
        url,
        body,
        Authorization: "Bearer #{bearer_token}",
        "Content-Type": "application/json"
      )

    %{status_code: status_code, body: Jason.decode!(body_json, keys: :atoms)}
  end

  defp get_with_authentication(url, bearer_token) do
    %{
      status_code: status_code,
      body: body_json
    } =
      HTTPoison.get!(
        url,
        Authorization: "Bearer #{bearer_token}",
        "Content-Type": "application/json"
      )

    %{status_code: status_code, body: Jason.decode!(body_json, keys: :atoms)}
  end

  defp auth0_setup do
    secret_key = Application.get_env(:discovery_api, TokenHandler) |> Keyword.get(:secret_key)
    GuardianConfigurator.configure(issuer: AuthHelper.valid_issuer())

    really_far_in_the_future = 3_000_000_000_000
    AuthHelper.set_allowed_guardian_drift(really_far_in_the_future)

    bypass = Bypass.open()

    Bypass.stub(bypass, "GET", "/jwks", fn conn ->
      Plug.Conn.resp(conn, :ok, Jason.encode!(AuthHelper.valid_jwks()))
    end)

    Bypass.stub(bypass, "GET", "/userinfo", fn conn ->
      Plug.Conn.resp(conn, :ok, Jason.encode!(%{"email" => "x@y.z"}))
    end)

    Application.put_env(:discovery_api, :jwks_endpoint, "http://localhost:#{bypass.port}/jwks")
    Application.put_env(:discovery_api, :user_info_endpoint, "http://localhost:#{bypass.port}/userinfo")

    fn ->
      AuthHelper.set_allowed_guardian_drift(0)
      GuardianConfigurator.configure(secret_key: secret_key)
    end
  end
end
