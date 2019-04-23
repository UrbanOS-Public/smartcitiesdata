defmodule DiscoveryApiWeb.DatasetPreviewControllerTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo

  @dataset_id "1234-4567-89101"
  @system_name "foobar__company_data"

  describe "preview dataset data" do
    setup do
      dataset_json = Jason.encode!(%{id: @dataset_id, systemName: @system_name, private: false})

      allow(Redix.command!(:redix, ["GET", "discovery-api:dataset:#{@dataset_id}"]), return: dataset_json)
      allow(Redix.command!(:redix, ["GET", "forklift:last_insert_date:#{@dataset_id}"]), return: nil)
      count_keys = ["smart_registry:queries:count:#{@dataset_id}", "smart_registry:downloads:count:#{@dataset_id}"]
      allow(Redix.command!(:redix, ["MGET" | count_keys]), return: ["7", "9"])
      allow(Redix.command!(:redix, ["KEYS", "smart_registry:*:count:#{@dataset_id}"]), return: count_keys)
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

      expect(DiscoveryApiWeb.DatasetPrestoQueryService.preview(@system_name), return: list_of_maps)
      expect(DiscoveryApiWeb.DatasetPrestoQueryService.preview_columns(@system_name), return: list_of_columns)
      actual = conn |> get("/api/v1/dataset/#{@dataset_id}/preview") |> json_response(200)

      assert expected == actual
    end

    test "preview controller returns an empty list for an existing dataset with no data", %{conn: conn} do
      list_of_columns = ["id", "name"]
      expected = %{"data" => [], "meta" => %{"columns" => list_of_columns}}

      expect(DiscoveryApiWeb.DatasetPrestoQueryService.preview(@system_name), return: [])
      expect(DiscoveryApiWeb.DatasetPrestoQueryService.preview_columns(@system_name), return: list_of_columns)
      actual = conn |> get("/api/v1/dataset/#{@dataset_id}/preview") |> json_response(200)

      assert expected == actual
    end
  end

  describe "preview restricted dataset" do
    setup do
      organization = TDG.create_organization(%{dn: "cn=this_is_a_group,ou=Group"})

      dataset =
        Helper.sample_dataset(%{
          id: @dataset_id,
          private: true,
          organizationDetails: organization,
          systemName: @system_name
        })

      allow DiscoveryApi.Data.Dataset.get(dataset.id), return: dataset

      allow SmartCity.Organization.get(dataset.organizationDetails.id), return: organization

      list_of_maps = [
        %{"id" => Faker.UUID.v4(), name: Faker.Lorem.characters(3..10)},
        %{"id" => Faker.UUID.v4(), name: Faker.Lorem.characters(3..10)},
        %{"id" => Faker.UUID.v4(), name: Faker.Lorem.characters(3..10)}
      ]

      list_of_columns = ["id", "name"]

      allow(DiscoveryApiWeb.DatasetPrestoQueryService.preview(@system_name), return: list_of_maps)
      allow(DiscoveryApiWeb.DatasetPrestoQueryService.preview_columns(@system_name), return: list_of_columns)

      :ok
    end

    test "does not preview a restricted dataset if the given user is not a member of the dataset's group", %{conn: conn} do
      username = "bigbadbob"
      ldap_user = Helper.ldap_user()
      ldap_group = Helper.ldap_group(%{"member" => ["uid=FirstUser,ou=People"]})

      allow Paddle.authenticate(any(), any()), return: :ok
      allow Paddle.config(:account_subdn), return: "ou=People"
      allow Paddle.get(filter: [uid: username]), return: {:ok, [ldap_user]}
      allow Paddle.get(base: [ou: "Group"], filter: [cn: "this_is_a_group"]), return: {:ok, [ldap_group]}

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

      allow Paddle.authenticate(any(), any()), return: :ok
      allow Paddle.config(:account_subdn), return: "ou=People"
      allow Paddle.get(filter: [uid: username]), return: {:ok, [ldap_user]}
      allow Paddle.get(base: [ou: "Group"], filter: [cn: "this_is_a_group"]), return: {:ok, [ldap_group]}

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

      allow Paddle.authenticate(any(), any()), return: :ok
      allow Paddle.config(:account_subdn), return: "ou=People"
      allow Paddle.get(filter: [uid: username]), return: {:ok, [ldap_user]}
      allow Paddle.get(base: [ou: "Group"], filter: [cn: "this_is_a_group"]), return: {:ok, [ldap_group]}

      {:ok, token, _} = DiscoveryApi.Auth.Guardian.encode_and_sign(username, %{}, token_type: "refresh")

      conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> get("/api/v1/dataset/#{@dataset_id}/preview")
      |> json_response(200)
    end
  end
end
