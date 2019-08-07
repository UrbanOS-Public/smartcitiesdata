defmodule DiscoveryApiWeb.DatasetPreviewControllerTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo
  alias DiscoveryApi.Data.{Model, SystemNameCache}
  alias DiscoveryApiWeb.Services.PrestoService

  @dataset_id "1234-4567-89101"
  @system_name "foobar__company_data"
  @org_name "org1"
  @data_name "data1"

  describe "preview dataset data" do
    setup do
      model =
        Helper.sample_model(%{
          id: @dataset_id,
          systemName: @system_name,
          private: false,
          lastUpdatedDate: nil,
          queries: 7,
          downloads: 9
        })

      allow(Model.get(model.id), return: model)
      :ok
    end

    test "preview controller returns data from preview service", %{conn: conn} do
      list_of_maps = [
        %{"id" => Faker.UUID.v4(), name: Faker.Lorem.characters(3..10)},
        %{"id" => Faker.UUID.v4(), name: Faker.Lorem.characters(3..10)},
        %{"id" => Faker.UUID.v4(), name: Faker.Lorem.characters(3..10)}
      ]

      encoded_maps =
        list_of_maps
        |> Jason.encode!()
        |> Jason.decode!()

      list_of_columns = ["id", "name"]

      expected = %{"data" => encoded_maps, "meta" => %{"columns" => list_of_columns}}

      expect(PrestoService.preview(@system_name), return: list_of_maps)
      expect(PrestoService.preview_columns(@system_name), return: list_of_columns)
      actual = conn |> get("/api/v1/dataset/#{@dataset_id}/preview") |> json_response(200)

      assert expected == actual
    end

    test "preview controller returns an empty list for an existing dataset with no data", %{conn: conn} do
      list_of_columns = ["id", "name"]
      expected = %{"data" => [], "meta" => %{"columns" => list_of_columns}}

      expect(PrestoService.preview(@system_name), return: [])
      expect(PrestoService.preview_columns(@system_name), return: list_of_columns)
      actual = conn |> get("/api/v1/dataset/#{@dataset_id}/preview") |> json_response(200)

      assert expected == actual
    end

    test "preview controller returns _SOMETHING_ when table does not exist", %{conn: conn} do
      expected = %{"data" => [], "meta" => %{"columns" => []}, "message" => "Something went wrong while fetching the preview."}

      allow PrestoService.preview_columns(any()), return: []
      allow PrestoService.preview(any()), exec: fn _ -> raise Prestige.Error, message: "Test error" end
      actual = conn |> get("/api/v1/dataset/#{@dataset_id}/preview") |> json_response(200)

      assert expected == actual
    end
  end

  describe "preview restricted dataset" do
    setup do
      model =
        Helper.sample_model(%{
          id: @dataset_id,
          systemName: @system_name,
          name: @data_name,
          private: true,
          lastUpdatedDate: nil,
          queries: 7,
          downloads: 9,
          organizationDetails: %{
            orgName: @org_name,
            dn: "cn=this_is_a_group,ou=Group"
          }
        })

      allow(SystemNameCache.get(@org_name, @data_name), return: @dataset_id)
      allow(Model.get(@dataset_id), return: model)

      list_of_maps = [
        %{"id" => Faker.UUID.v4(), name: Faker.Lorem.characters(3..10)},
        %{"id" => Faker.UUID.v4(), name: Faker.Lorem.characters(3..10)},
        %{"id" => Faker.UUID.v4(), name: Faker.Lorem.characters(3..10)}
      ]

      list_of_columns = ["id", "name"]

      allow(PrestoService.preview(@system_name), return: list_of_maps)
      allow(PrestoService.preview_columns(@system_name), return: list_of_columns)

      :ok
    end

    test "does not preview a restricted dataset if the given user is not a member of the dataset's group", %{conn: conn} do
      username = "bigbadbob"
      ldap_user = Helper.ldap_user()
      ldap_group = Helper.ldap_group(%{"member" => ["uid=FirstUser,ou=People"]})

      allow PaddleWrapper.authenticate(any(), any()), return: :ok
      allow PaddleWrapper.get(filter: [uid: username]), return: {:ok, [ldap_user]}
      allow PaddleWrapper.get(base: [ou: "Group"], filter: [cn: "this_is_a_group"]), return: {:ok, [ldap_group]}

      {:ok, token, _} = DiscoveryApi.Auth.Guardian.encode_and_sign(username, %{}, token_type: "refresh")

      conn
      |> put_req_cookie(Helper.default_guardian_token_key(), token)
      |> get("/api/v1/dataset/#{@dataset_id}/preview")
      |> json_response(404)
    end

    test "previews a restricted dataset if the given user has access to it, via cookie", %{conn: conn} do
      username = "bigbadbob"
      ldap_user = Helper.ldap_user()
      ldap_group = Helper.ldap_group(%{"member" => ["uid=#{username},ou=People"]})

      allow PaddleWrapper.authenticate(any(), any()), return: :ok
      allow PaddleWrapper.get(filter: [uid: username]), return: {:ok, [ldap_user]}
      allow PaddleWrapper.get(base: [ou: "Group"], filter: [cn: "this_is_a_group"]), return: {:ok, [ldap_group]}

      {:ok, token, _} = DiscoveryApi.Auth.Guardian.encode_and_sign(username, %{}, token_type: "refresh")

      conn
      |> put_req_cookie(Helper.default_guardian_token_key(), token)
      |> get("/api/v1/dataset/#{@dataset_id}/preview")
      |> json_response(200)
    end

    test "previews a restricted dataset if the given user has access to it, via token", %{conn: conn} do
      username = "bigbadbob"
      ldap_user = Helper.ldap_user()
      ldap_group = Helper.ldap_group(%{"member" => ["uid=#{username},ou=People"]})

      allow PaddleWrapper.authenticate(any(), any()), return: :ok
      allow PaddleWrapper.get(filter: [uid: username]), return: {:ok, [ldap_user]}
      allow PaddleWrapper.get(base: [ou: "Group"], filter: [cn: "this_is_a_group"]), return: {:ok, [ldap_group]}

      {:ok, token, _} = DiscoveryApi.Auth.Guardian.encode_and_sign(username, %{}, token_type: "refresh")

      conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> get("/api/v1/dataset/#{@dataset_id}/preview")
      |> json_response(200)
    end
  end

  describe "fetch geojson dataset" do
    test "retrieves geojson dataset", %{conn: conn} do
      dataset_name = "the_dataset"
      dataset_id = "the_dataset_id"
      row_limit = 10

      model = Helper.sample_model(%{id: dataset_id, name: dataset_name, sourceFormat: "geojson", systemName: dataset_name})

      allow(Model.get(dataset_id), return: model)

      allow(DiscoveryApiWeb.Services.PrestoService.preview(dataset_name, row_limit),
        return: [%{"features" => "{}"}, %{"features" => "{}"}, %{"features" => "{}"}]
      )

      expected = %{
        "type" => "FeatureCollection",
        "name" => model.name,
        "features" => [%{}, %{}, %{}]
      }

      actual =
        conn
        |> put_resp_header("accepts", "application/geo+json")
        |> get("/api/v1/dataset/#{dataset_id}/features_preview")
        |> json_response(200)

      assert expected == actual
    end
  end
end
