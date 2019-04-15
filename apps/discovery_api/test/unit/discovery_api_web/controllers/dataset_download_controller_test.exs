defmodule DiscoveryApiWeb.DatasetDownloadControllerTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo
  import Checkov
  alias SmartCity.TestDataGenerator, as: TDG
  alias DiscoveryApi.Data.SystemNameCache

  @dataset_id "1234-4567-89101"
  @system_name "foobar__company_data"
  @org_name "org1"
  @data_name "data1"

  describe "fetching csv data" do
    setup do
      org = TDG.create_organization(id: "org-id", orgName: @org_name)
      dataset = TDG.create_dataset(id: @dataset_id, technical: %{orgId: "org-id", dataName: @data_name})
      allow SmartCity.Organization.get(any()), return: {:ok, org}
      SystemNameCache.put(dataset)

      allow(Prestige.execute("describe #{@system_name}"),
        return: []
      )

      allow(Prestige.execute("select * from #{@system_name}"),
        return: [[1, 2, 3], [4, 5, 6]]
      )

      allow(Prestige.prefetch(any()),
        return: [["id", "1", "4"], ["one", "2", "5"], ["two", "3", "6"]]
      )

      dataset_json = Jason.encode!(%{id: @dataset_id, systemName: @system_name})

      allow(Redix.command!(:redix, ["GET", "discovery-api:dataset:#{@dataset_id}"]), return: dataset_json)
      allow(Redix.command!(:redix, ["GET", "forklift:last_insert_date:#{@dataset_id}"]), return: nil)
      allow(Redix.command!(any(), any()), return: :does_not_matter)

      :ok
    end

    data_test "returns data in CSV format, given an accept header for it", %{conn: conn} do
      conn = conn |> put_req_header("accept", "text/csv")
      actual = conn |> get(url) |> response(200)
      assert "id,one,two\n1,2,3\n4,5,6\n" == actual

      where(
        url: [
          "/api/v1/dataset/1234-4567-89101/download",
          "/api/v1/organization/org1/dataset/data1/download"
        ]
      )
    end

    data_test "returns data in CSV format, given an accept header for it ", %{conn: conn} do
      conn = conn |> put_req_header("accept", "text/csv")
      actual = conn |> get(url) |> response(200)
      assert "id,one,two\n1,2,3\n4,5,6\n" == actual

      where(
        url: [
          "/api/v1/dataset/1234-4567-89101/download",
          "/api/v1/organization/org1/dataset/data1/download"
        ]
      )
    end

    data_test "returns data in CSV format, given a query parameter for it", %{conn: conn} do
      actual = conn |> get(url) |> response(200)
      assert "id,one,two\n1,2,3\n4,5,6\n" == actual

      where(
        url: [
          "/api/v1/dataset/1234-4567-89101/download?_format=csv",
          "/api/v1/organization/org1/dataset/data1/download?_format_csv"
        ]
      )
    end

    data_test "returns data in CSV format, given no accept header", %{conn: conn} do
      actual = conn |> get(url) |> response(200)
      assert "id,one,two\n1,2,3\n4,5,6\n" == actual

      where(
        url: [
          "/api/v1/dataset/1234-4567-89101/download",
          "/api/v1/organization/org1/dataset/data1/download"
        ]
      )
    end

    data_test "increments dataset download count when dataset download is requested", %{conn: conn} do
      conn |> get(url) |> response(200)
      assert_called(Redix.command!(:redix, ["INCR", "smart_registry:downloads:count:#{@dataset_id}"]))

      where(
        url: [
          "/api/v1/dataset/1234-4567-89101/download?_format=csv",
          "/api/v1/organization/org1/dataset/data1/download?_format_csv"
        ]
      )
    end
  end

  describe "fetching json data" do
    setup do
      org = TDG.create_organization(id: "org-id", orgName: @org_name)

      dataset =
        TDG.create_dataset(
          id: @dataset_id,
          technical: %{orgId: org.id, dataName: @data_name, systemName: @system_name}
        )

      allow SmartCity.Organization.get(any()), return: {:ok, org}
      SystemNameCache.put(dataset)

      allow(
        Prestige.execute("select * from #{@system_name}", rows_as_maps: true),
        return: [%{id: 1, name: "Joe", age: 21}, %{id: 2, name: "Robby", age: 32}]
      )

      dataset_json = Jason.encode!(%{id: @dataset_id, systemName: @system_name})
      allow(Redix.command!(:redix, ["GET", "discovery-api:dataset:#{@dataset_id}"]), return: dataset_json)
      allow(Redix.command!(:redix, ["GET", "forklift:last_insert_date:#{@dataset_id}"]), return: nil)

      allow(Redix.command!(any(), any()), return: :does_not_matter)

      :ok
    end

    data_test "returns data in JSON format, given an accept header for it", %{conn: conn} do
      conn = put_req_header(conn, "accept", "application/json")
      actual = conn |> get(url) |> response(200)

      assert Jason.decode!(actual) == [
               %{"id" => 1, "name" => "Joe", "age" => 21},
               %{"id" => 2, "name" => "Robby", "age" => 32}
             ]

      where(
        url: [
          "/api/v1/dataset/1234-4567-89101/download",
          "/api/v1/organization/org1/dataset/data1/download"
        ]
      )
    end

    data_test "returns data in JSON format, given a query parameter for it", %{conn: conn} do
      actual = conn |> get(url) |> response(200)

      assert Jason.decode!(actual) == [
               %{"id" => 1, "name" => "Joe", "age" => 21},
               %{"id" => 2, "name" => "Robby", "age" => 32}
             ]

      where(
        url: [
          "/api/v1/dataset/1234-4567-89101/download?_format=json",
          "/api/v1/organization/org1/dataset/data1/download?_format=json"
        ]
      )
    end

    data_test "increments downloads count for dataset when dataset download requested", %{conn: conn} do
      conn |> get(url) |> response(200)
      assert_called(Redix.command!(:redix, ["INCR", "smart_registry:downloads:count:#{@dataset_id}"]))

      where(
        url: [
          "/api/v1/dataset/1234-4567-89101/download?_format=json",
          "/api/v1/organization/org1/dataset/data1/download?_format=json"
        ]
      )
    end
  end

  describe "download restricted dataset" do
    setup do
      allow(Redix.command!(:redix, ["GET", "forklift:last_insert_date:#{@dataset_id}"]), return: nil)

      allow(Redix.command!(any(), any()), return: :does_not_matter)

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

      allow(Prestige.execute("describe #{@system_name}"),
        return: []
      )

      allow(Prestige.execute("select * from #{@system_name}", rows_as_maps: true),
        return: [%{id: 1, name: "Joe", age: 21}, %{id: 2, name: "Robby", age: 32}]
      )

      allow(Prestige.prefetch(any()),
        return: [["id", "1", "4"], ["one", "2", "5"], ["two", "3", "6"]]
      )

      :ok
    end

    test "does not download a restricted dataset if the given user is not a member of the dataset's group", %{conn: conn} do
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
      |> put_req_header("accept", "application/json")
      |> get("/api/v1/dataset/#{@dataset_id}/download")
      |> json_response(404)
    end

    test "downloads a restricted dataset if the given user has access to it, via cookie", %{conn: conn} do
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
      |> put_req_header("accept", "application/json")
      |> get("/api/v1/dataset/#{@dataset_id}/download")
      |> json_response(200)
    end

    test "downloads a restricted dataset if the given user has access to it, via token", %{conn: conn} do
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
      |> put_req_header("accept", "application/json")
      |> get("/api/v1/dataset/#{@dataset_id}/download")
      |> json_response(200)
    end
  end
end
