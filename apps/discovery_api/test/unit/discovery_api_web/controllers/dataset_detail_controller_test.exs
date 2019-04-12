defmodule DiscoveryApiWeb.DatasetDetailControllerTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo
  alias Plug.Conn
  alias DiscoveryApi.Test.Helper

  @dataset_id "123"

  describe "fetch dataset detail" do
    test "retrieves dataset + organization from retriever when organization found", %{conn: conn} do
      dataset = Helper.sample_dataset()

      expect DiscoveryApi.Data.Dataset.get(dataset.id), return: dataset

      actual = conn |> get("/api/v1/dataset/#{dataset.id}") |> json_response(200)

      assert %{
               "id" => dataset.id,
               "name" => dataset.name,
               "title" => dataset.title,
               "description" => dataset.description,
               "keywords" => dataset.keywords,
               "organization" => %{
                 "name" => dataset.organizationDetails.orgName,
                 "title" => dataset.organizationDetails.orgTitle,
                 "image" => dataset.organizationDetails.logoUrl,
                 "description" => dataset.organizationDetails.description,
                 "homepage" => dataset.organizationDetails.homepage
               },
               "sourceType" => dataset.sourceType,
               "sourceFormat" => dataset.sourceFormat,
               "sourceUrl" => dataset.sourceUrl,
               "lastUpdatedDate" => nil,
               "contactName" => dataset.contactName,
               "contactEmail" => dataset.contactEmail,
               "license" => dataset.license,
               "rights" => dataset.rights,
               "homepage" => dataset.homepage,
               "spatial" => dataset.spatial,
               "temporal" => dataset.temporal,
               "publishFrequency" => dataset.publishFrequency,
               "conformsToUri" => dataset.conformsToUri,
               "describedByUrl" => dataset.describedByUrl,
               "describedByMimeType" => dataset.describedByMimeType,
               "parentDataset" => dataset.parentDataset,
               "issuedDate" => dataset.issuedDate,
               "language" => dataset.language,
               "referenceUrls" => dataset.referenceUrls,
               "categories" => dataset.categories,
               "modified" => dataset.modified
             } == actual
    end

    test "returns 404", %{conn: conn} do
      expect(DiscoveryApi.Data.Dataset.get(any()), return: nil)

      conn |> get("/api/v1/dataset/xyz123") |> json_response(404)
    end
  end

  describe "fetch restricted dataset detail" do
    setup do
      organization = TDG.create_organization(%{dn: "cn=this_is_a_group,ou=Group"})
      dataset = Helper.sample_dataset(%{id: @dataset_id, private: true, organizationDetails: organization})

      allow DiscoveryApi.Data.Dataset.get(dataset.id), return: dataset

      allow SmartCity.Organization.get(dataset.organizationDetails.id), return: organization

      :ok
    end

    test "does not retrieve a restricted dataset if the given user does not have access to it", %{conn: conn} do
      ldap_user = Helper.ldap_user()

      ldap_group = Helper.ldap_group(%{"member" => ["uid=FirstUser,ou=People"]})

      allow Paddle.authenticate(any(), any()), return: :ok
      allow Paddle.config(:account_subdn), return: "ou=People"
      allow Paddle.get(filter: [uid: "bigbadbob"]), return: {:ok, [ldap_user]}
      allow Paddle.get(base: [ou: "Group"], filter: [cn: "this_is_a_group"]), return: {:ok, [ldap_group]}

      {:ok, token, _} = DiscoveryApi.Auth.Guardian.encode_and_sign("bigbadbob")

      conn
      |> Conn.put_req_header("authorization", "Bearer " <> token)
      |> get("/api/v1/dataset/#{@dataset_id}")
      |> json_response(404)
    end

    test "retrieves a restricted dataset if the given user has access to it", %{conn: conn} do
      ldap_user = Helper.ldap_user()

      ldap_group = Helper.ldap_group(%{"member" => ["uid=bigbadbob,ou=People"]})

      allow Paddle.authenticate(any(), any()), return: :ok
      allow Paddle.config(:account_subdn), return: "ou=People"
      allow Paddle.get(filter: [uid: "bigbadbob"]), return: {:ok, [ldap_user]}
      allow Paddle.get(base: [ou: "Group"], filter: [cn: "this_is_a_group"]), return: {:ok, [ldap_group]}

      {:ok, token, _} = DiscoveryApi.Auth.Guardian.encode_and_sign("bigbadbob")

      conn
      |> Conn.put_req_header("authorization", "Bearer " <> token)
      |> get("/api/v1/dataset/#{@dataset_id}")
      |> json_response(200)
    end
  end
end
