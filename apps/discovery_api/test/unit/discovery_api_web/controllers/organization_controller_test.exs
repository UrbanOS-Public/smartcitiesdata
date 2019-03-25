defmodule DiscoveryApiWeb.OrganizationControllerTest do
  alias SmartCity.Organization
  alias DiscoveryApi.Data.Persistence
  # alias DiscoveryApiWeb.OrganizationController
  use DiscoveryApiWeb.ConnCase
  use Placebo

  @cache DiscoveryApiWeb.OrganizationController.cache_name()

  setup do
    Cachex.clear(@cache)
    :ok
  end

  describe "organization controller" do
    test "fetches organization from redis by org id", %{conn: conn} do
      expected = %Organization{
        id: "1234",
        orgName: "Org Name",
        orgTitle: "Org Title",
        description: nil,
        homepage: nil,
        logoUrl: nil
      }

      expect(Persistence.get("smart_city:organization:latest:1234"), return: Jason.encode!(expected))
      actual = conn |> get("/api/v1/organization/1234") |> json_response(200)

      assert Jason.encode!(expected) == actual
    end

    test "returns 404 if organization does not exist", %{conn: conn} do
      expect(Persistence.get("smart_city:organization:latest:1234"), return: nil)
      actual = conn |> get("/api/v1/organization/1234") |> json_response(404)

      assert %{"message" => "Not Found"} = actual
    end

    test "fetches org from cache if loaded into cache", %{conn: conn} do
      expected = %{
        "id" => "1234",
        "orgName" => "Org Name",
        "orgTitle" => "Org Title",
        "description" => nil,
        "homepage" => nil,
        "logoUrl" => nil
      }

      expect(Cachex.get!(any(), "1234"), return: expected)
      actual = conn |> get("/api/v1/organization/1234") |> json_response(200)

      assert expected == actual
    end
  end
end
