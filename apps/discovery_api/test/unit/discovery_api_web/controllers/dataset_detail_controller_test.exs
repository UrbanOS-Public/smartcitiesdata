defmodule DiscoveryApiWeb.DatasetDetailControllerTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo
  alias DiscoveryApi.Test.Helper
  alias SmartCity.TestDataGenerator, as: TDG

  describe "fetch dataset detail" do
    test "retrieves dataset + organization from retriever when organization found", %{conn: conn} do
      dataset = Helper.sample_dataset()

      expect DiscoveryApi.Data.Dataset.get(dataset.id), return: dataset

      actual = conn |> get("/api/v1/dataset/#{dataset.id}") |> json_response(200)

      assert %{
               "id" => dataset.id,
               "name" => dataset.title,
               "description" => dataset.description,
               "keywords" => dataset.keywords,
               "organization" => %{
                 "name" => dataset.organizationDetails.orgTitle,
                 "image" => dataset.organizationDetails.logoUrl,
                 "description" => dataset.organizationDetails.description,
                 "homepage" => dataset.organizationDetails.homepage
               },
               "sourceType" => dataset.sourceType,
               "sourceUrl" => dataset.sourceUrl
             } == actual
    end

    test "returns 404", %{conn: conn} do
      expect(DiscoveryApi.Data.Dataset.get(any()), return: nil)

      conn |> get("/api/v1/dataset/xyz123") |> json_response(404)
    end
  end

  describe "fetch restricted dataset detail" do
    test "does not retrieve a restricted dataset if the given user does not have access to it", %{conn: conn} do
      organization = TDG.create_organization(%{dn: "cn=this_is_a_group,ou=Group"})
      dataset = Helper.sample_dataset(%{private: true, organizationDetails: organization})

      allow DiscoveryApi.Data.Dataset.get(dataset.id),
        return: dataset

      allow SmartCity.Organization.get(dataset.organizationDetails.id), return: organization

      ldap_user = %{
        "cn" => ["bigbadbob"],
        "displayName" => ["big bad"],
        "dn" => "uid=bigbadbob,cn=users,cn=accounts",
        "memberOf" => ["cn=my_first_dn,cn=groups,cn=accounts,dc=internal,dc=smartcolumbusos,dc=com"],
        "ou" => ["People"],
        "sn" => ["bad"],
        "uid" => ["bigbadbob"],
        "uidNumber" => ["1501200034"]
      }

      ldap_group = %{
        "cn" => ["this_is_a_group"],
        "dn" => "cn=this_is_a_group,ou=Group",
        "member" => ["cn=FirstUser,ou=People"],
        "objectClass" => ["top", "groupOfNames"]
      }

      allow Paddle.authenticate(any(), any()), return: :ok
      allow Paddle.get(base: [uid: "bigbadbob", ou: "People"]), return: {:ok, [ldap_user]}
      allow Paddle.get(base: "cn=this_is_a_group,ou=Group"), return: {:ok, [ldap_group]}
      {:ok, token, _} = DiscoveryApi.Auth.Guardian.encode_and_sign("bigbadbob")

      conn
      |> Plug.Conn.put_req_header("token", token)
      |> get("/api/v1/dataset/#{dataset.id}")
      |> json_response(401)
    end
  end

  test "retrieves a restricted dataset if the given user has access to it", %{conn: conn} do
    organization = TDG.create_organization(%{dn: "cn=this_is_a_group,ou=Group"})
    dataset = Helper.sample_dataset(%{private: true, organizationDetails: organization})

    allow DiscoveryApi.Data.Dataset.get(dataset.id),
      return: dataset

    allow SmartCity.Organization.get(dataset.organizationDetails.id), return: organization

    ldap_user = %{
      "cn" => ["bigbadbob"],
      "displayName" => ["big bad"],
      "dn" => "uid=bigbadbob,cn=users,cn=accounts",
      "memberOf" => ["cn=my_first_dn,cn=groups,cn=accounts,dc=internal,dc=smartcolumbusos,dc=com"],
      "ou" => ["People"],
      "sn" => ["bad"],
      "uid" => ["bigbadbob"],
      "uidNumber" => ["1501200034"]
    }

    ldap_group = %{
      "cn" => ["this_is_a_group"],
      "dn" => "cn=this_is_a_group,ou=Group",
      "member" => ["cn=bigbadbob,ou=People"],
      "objectClass" => ["top", "groupOfNames"]
    }

    allow Paddle.authenticate(any(), any()), return: :ok
    allow Paddle.get(base: [uid: "bigbadbob", ou: "People"]), return: {:ok, [ldap_user]}
    allow Paddle.get(base: "cn=this_is_a_group,ou=Group"), return: {:ok, [ldap_group]}
    {:ok, token, _} = DiscoveryApi.Auth.Guardian.encode_and_sign("bigbadbob")

    conn
    |> Plug.Conn.put_req_header("token", token)
    |> get("/api/v1/dataset/#{dataset.id}")
    |> json_response(200)
  end
end
