defmodule DiscoveryApiWeb.DatasetPreviewControllerTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo

  @dataset_id "1234-4567-89101"
  @system_name "foobar__company_data"

  describe "preview dataset data" do
    setup do
      dataset_json = Jason.encode!(%{id: @dataset_id, systemName: @system_name})

      allow(Redix.command!(:redix, ["GET", "discovery-api:dataset:#{@dataset_id}"]), return: dataset_json)
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

      expected = %{"data" => encoded_maps}

      expect(DiscoveryApiWeb.DatasetPrestoQueryService.preview(@system_name), return: list_of_maps)
      actual = conn |> get("/api/v1/dataset/#{@dataset_id}/preview") |> json_response(200)

      assert expected == actual
    end

    test "preview controller returns an empty list for an existing dataset with no data", %{conn: conn} do
      expected = %{"data" => []}

      expect(DiscoveryApiWeb.DatasetPrestoQueryService.preview(@system_name), return: [])
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

      allow(DiscoveryApiWeb.DatasetPrestoQueryService.preview(@system_name), return: list_of_maps)

      :ok
    end

    test "does not preview a restricted dataset if the given user does not have access to it", %{conn: conn} do
      ldap_user = Helper.ldap_user()

      ldap_group = Helper.ldap_group(%{"member" => ["cn=FirstUser,ou=People"]})

      allow Paddle.authenticate(any(), any()), return: :ok
      allow Paddle.get(base: [uid: "bigbadbob", ou: "People"]), return: {:ok, [ldap_user]}
      allow Paddle.get(base: "cn=this_is_a_group,ou=Group"), return: {:ok, [ldap_group]}

      {:ok, token, _} = DiscoveryApi.Auth.Guardian.encode_and_sign("bigbadbob")

      conn
      |> Plug.Conn.put_req_header("token", token)
      |> get("/api/v1/dataset/#{@dataset_id}/preview")
      |> json_response(404)
    end

    test "previews a restricted dataset if the given user has access to it", %{conn: conn} do
      ldap_user = Helper.ldap_user()

      ldap_group = Helper.ldap_group(%{"member" => ["cn=bigbadbob,ou=People"]})

      allow Paddle.authenticate(any(), any()), return: :ok
      allow Paddle.get(base: [uid: "bigbadbob", ou: "People"]), return: {:ok, [ldap_user]}
      allow Paddle.get(base: "cn=this_is_a_group,ou=Group"), return: {:ok, [ldap_group]}

      {:ok, token, _} = DiscoveryApi.Auth.Guardian.encode_and_sign("bigbadbob")

      conn
      |> Plug.Conn.put_req_header("token", token)
      |> get("/api/v1/dataset/#{@dataset_id}/preview")
      |> json_response(200)
    end
  end
end
