defmodule DiscoveryApi.Auth.AuthTest do
  use ExUnit.Case
  use DiscoveryApi.DataCase
  use DiscoveryApiWeb.Test.AuthConnCase.IntegrationCase
  use Placebo

  import ExUnit.CaptureLog
  import SmartCity.TestHelper, only: [eventually: 3]

  alias DiscoveryApi.Test.Helper
  alias DiscoveryApi.Schemas.Users
  alias DiscoveryApi.Schemas.Visualizations
  alias DiscoveryApi.Repo

  @moduletag capture_log: true

  @organization_1_name "organization_one"
  @organization_2_name "organization_two"

  setup_all do
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
    setup %{private_model_that_belongs_to_org_1: model, authorized_subject: subject} do
      user = Helper.create_persisted_user(subject)
      Helper.associate_user_with_organization(user.subject_id, model.organizationDetails.id)
    end

    test "is able to access a restricted dataset with a valid token", setup_map do
      allow(RaptorService.is_authorized_by_user_id(any(), any(), any()), return: true)

      body =
        get(setup_map.authorized_conn, "/api/v1/dataset/#{setup_map.private_model_that_belongs_to_org_1.id}")
        |> json_response(200)

      assert body["id"] == setup_map[:private_model_that_belongs_to_org_1].id
    end

    test "is not able to access a restricted dataset with a bad token", setup_map do
      body =
        get(setup_map.invalid_conn, "/api/v1/dataset/#{setup_map.private_model_that_belongs_to_org_1.id}")
        |> response(401)
        |> Jason.decode!()

      assert body == %{"message" => "Unauthorized"}
    end
  end

  describe "POST /logged-in" do
    test "returns 'OK' when token is valid", setup_map do
      assert post(setup_map.authorized_conn, "/api/v1/logged-in")
             |> response(200)
    end

    test "login is IDEMpotent", setup_map do
      assert post(setup_map.authorized_conn, "/api/v1/logged-in")
             |> response(200)

      assert post(setup_map.authorized_conn, "/api/v1/logged-in")
             |> response(200)
    end

    test "saves logged in user", setup_map do
      subject_id = setup_map.authorized_subject

      assert post(setup_map.authorized_conn, "/api/v1/logged-in")
             |> response(200)

      eventually(
        fn ->
          assert {:ok, actual} = Users.get_user(subject_id, :subject_id)

          assert subject_id == actual.subject_id
          assert "x@y.z" == actual.email
          assert actual.id != nil
        end,
        2000,
        10
      )
    end

    test "returns 'unauthorized' when token is invalid", setup_map do
      assert post(setup_map.invalid_conn, "/api/v1/logged-in")
             |> response(401)
    end
  end

  describe "POST /logged-out" do
    test "logout is not idempotent", setup_map do
      assert post(setup_map.revocable_conn, "/api/v1/logged-in")
             |> response(200)

      assert post(setup_map.revocable_conn, "/api/v1/logged-out")
             |> response(200)

      assert post(setup_map.revocable_conn, "/api/v1/logged-in")
             |> response(401)
    end

    test "when user is logged-out, they can't use their token to access protected resources, even when they attempt to login",
         %{private_model_that_belongs_to_org_1: model} = setup_map do
      subject = setup_map.revocable_subject
      model_id = model.id

      allow(RaptorService.is_authorized_by_user_id(any(),any(), any()), return: true)

      user = Helper.create_persisted_user(subject)
      Helper.associate_user_with_organization(user.subject_id, model.organizationDetails.id)

      assert post(setup_map.revocable_conn, "/api/v1/logged-in")
             |> response(200)

      assert %{"id" => ^model_id} =
               get(setup_map.revocable_conn, "/api/v1/dataset/#{model.id}/")
               |> json_response(200)

      assert post(setup_map.revocable_conn, "/api/v1/logged-out")
             |> response(200)

      allow(RaptorService.is_authorized_by_user_id(any(),any(), any()), return: true)

      assert %{"message" => "Unauthorized"} ==
               get(setup_map.revocable_conn, "/api/v1/dataset/#{model.id}/")
               |> response(401)
               |> Jason.decode!()

      assert post(setup_map.revocable_conn, "/api/v1/logged-in")
             |> response(401)

      assert %{"message" => "Unauthorized"} ==
               get(setup_map.revocable_conn, "/api/v1/dataset/#{model.id}/")
               |> response(401)
               |> Jason.decode!()
    end

    test "when user is logged-out, it doesn't affect other users", %{private_model_that_belongs_to_org_1: model} = setup_map do
      subject = setup_map.revocable_subject
      other_subject = setup_map.authorized_subject
      model_id = model.id

      user = Helper.create_persisted_user(subject)
      Helper.associate_user_with_organization(user.subject_id, model.organizationDetails.id)

      other_user = Helper.create_persisted_user(other_subject)
      Helper.associate_user_with_organization(other_user.subject_id, model.organizationDetails.id)

      allow(RaptorService.is_authorized_by_user_id(any(),user.subject_id, any()), return: false)
      allow(RaptorService.is_authorized_by_user_id(any(),other_user.subject_id, any()), return: true)

      assert post(setup_map.revocable_conn, "/api/v1/logged-in")
             |> response(200)

      assert post(setup_map.revocable_conn, "/api/v1/logged-out")
             |> response(200)

      assert %{"message" => "Unauthorized"} ==
               get(setup_map.revocable_conn, "/api/v1/dataset/#{model.id}/")
               |> response(401)
               |> Jason.decode!()

      assert %{"id" => ^model_id} =
               get(setup_map.authorized_conn, "/api/v1/dataset/#{model.id}/")
               |> json_response(200)
    end
  end

  describe "POST /visualization" do
    test "adds owner data to the newly created visualization", setup_map do
      user = Helper.create_persisted_user(setup_map.authorized_subject)
      post_body = ~s({"query": "select * from tarps", "title": "My favorite title", "chart": {"data": "hello"}})

      %{"id" => id} =
        post(setup_map.authorized_conn, "/api/v1/visualization", post_body)
        |> json_response(201)

      visualization = Visualizations.get_visualization_by_id(id) |> elem(1) |> Repo.preload(:owner)

      assert visualization.owner.subject_id == user.subject_id
    end

    test "returns 'unauthorized' when token is invalid", setup_map do
      post_body = ~s({"query": "select * from tarps", "title": "My favorite title", "chart": {"data": "hello"}})

      assert %{"message" => "Unauthorized"} ==
               post(setup_map.invalid_conn, "/api/v1/visualization", post_body)
               |> response(401)
               |> Jason.decode!()
    end
  end

  describe "GET /visualization/:id" do
    test "returns visualization for public table when user is anonymous",
         %{
           public_model_that_belongs_to_org_1: model,
           anonymous_conn: conn
         } do
      capture_log(fn ->
        DiscoveryApi.prestige_opts()
        |> Prestige.new_session()
        |> Prestige.query(~s|create table if not exists "#{model.systemName}" (id integer, name varchar)|)
      end)

      visualization = create_visualization(model.systemName)

      assert get(conn, "/api/v1/visualization/#{visualization.public_id}")
             |> json_response(200)
    end

    test "returns visualization for private table when user has access",
         %{
           private_model_that_belongs_to_org_1: model
         } = setup_map do
      user = Helper.create_persisted_user(setup_map.authorized_subject)
      Helper.associate_user_with_organization(user.subject_id, model.organizationDetails.id)
      allow(RaptorService.is_authorized_by_user_id(any(), any(), any()), return: true)

      capture_log(fn ->
        DiscoveryApi.prestige_opts()
        |> Prestige.new_session()
        |> Prestige.query(~s|create table if not exists "#{model.systemName}" (id integer, name varchar)|)
      end)

      visualization = create_visualization(model.systemName)

      assert get(setup_map.authorized_conn, "/api/v1/visualization/#{visualization.public_id}")
             |> json_response(200)
    end

    test "returns not found for private table when user is anonymous", %{
      private_model_that_belongs_to_org_1: model,
      anonymous_conn: conn
    } do
      capture_log(fn ->
        DiscoveryApi.prestige_opts()
        |> Prestige.new_session()
        |> Prestige.query(~s|create table if not exists "#{model.systemName}" (id integer, name varchar)|)
      end)

      DiscoveryApi.prestige_opts() |> Prestige.new_session() |> Prestige.query!("describe #{model.systemName}") |> Prestige.Result.as_maps()

      visualization = create_visualization(model.systemName)

      assert get(conn, "/api/v1/visualization/#{visualization.public_id}")
             |> response(404)
    end
  end

  defp create_visualization(table_name) do
    owner = Helper.create_persisted_user("me|you")
    {:ok, owner_with_orgs} = Users.get_user_with_organizations(owner.id)

    {:ok, visualization} =
      Visualizations.create_visualization(%{
        query: "select * from #{table_name}",
        title: "My first visualization",
        owner: owner_with_orgs
      })

    visualization
  end
end
