defmodule DiscoveryApiWeb.OrganizationControllerTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo
  alias DiscoveryApi.Schemas.Organizations
  alias DiscoveryApi.Schemas.Organizations.Organization

  @organization %Organization{
    id: "1234",
    name: "Org Name",
    title: "Org Title",
    description: "An Org",
    homepage: "http://homepage.org.com",
    logo_url: "http://logo.org.com"
  }

  describe "organization controller" do
    test "fetches organization from registry by org id", %{conn: conn} do
      expected = %{
        "id" => @organization.id,
        "name" => @organization.name,
        "title" => @organization.title,
        "description" => @organization.description,
        "homepage" => @organization.homepage,
        "logoUrl" => @organization.logo_url
      }

      expect(Organizations.get_organization("1234"), return: {:ok, @organization})
      actual = conn |> get("/api/v1/organization/1234") |> json_response(200)

      assert expected == actual
    end

    test "returns 404 if organization does not exist", %{conn: conn} do
      expect(Organizations.get_organization("1234"), return: {:error, "Does not exist"})
      actual = conn |> get("/api/v1/organization/1234") |> json_response(404)

      assert %{"message" => "Not Found"} = actual
    end
  end
end
