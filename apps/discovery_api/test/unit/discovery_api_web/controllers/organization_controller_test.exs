defmodule DiscoveryApiWeb.OrganizationControllerTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo
  alias SmartCity.Organization

  describe "organization controller" do
    test "fetches organization from registry by org id", %{conn: conn} do
      expected = %{
        "id" => "1234",
        "orgName" => "Org Name",
        "orgTitle" => "Org Title",
        "description" => nil,
        "homepage" => nil,
        "logoUrl" => nil
      }

      expect(Organization.get("1234"), return: {:ok, expected})
      actual = conn |> get("/api/v1/organization/1234") |> json_response(200)

      assert expected == actual
    end

    test "returns 404 if organization does not exist", %{conn: conn} do
      expect(Organization.get("1234"), return: {:error, "Does not exist"})
      actual = conn |> get("/api/v1/organization/1234") |> json_response(404)

      assert %{"message" => "Not Found"} = actual
    end
  end
end
