defmodule AndiTest do
  use ExUnit.Case
  use Divo

  alias SmartCity.Organization

  setup_all [:auth, :create_happy_path]

  describe "successful organization creation" do
    test "writes organization to LDAP", %{happy_path: expected} do
      expected_dn = "cn=#{expected.orgName}"
      assert {:ok, [actual]} = Paddle.get(filter: [cn: expected.orgName])
      assert Map.get(actual, "dn") == expected_dn
    end

    test "persists organization for downstream use", %{happy_path: expected} do
      assert {:ok, actual} = Organization.get(expected.id)
      assert actual.orgName == expected.orgName
    end
  end

  defp auth(_) do
    Paddle.authenticate([cn: "admin"], "admin")
  end

  defp create_happy_path(_) do
    org = organization(%{id: "happy-path"})
    create(org)
    [happy_path: org]
  end

  defp create(org) do
    struct = Jason.encode!(org)

    {:ok, _} =
      "http://localhost:4000/api/v1/organization"
      |> HTTPoison.post(struct, [{"content-type", "application/json"}])
  end

  defp organization(overrides) do
    org_map = %{
      id: "my-org-id",
      orgTitle: "My Organization",
      orgName: "myOrg",
      description: "test data",
      logoUrl: "https://google.com",
      homepage: "https://github.com"
    }

    {:ok, org} =
      org_map
      |> Map.merge(overrides)
      |> Organization.new()

    org
  end
end
