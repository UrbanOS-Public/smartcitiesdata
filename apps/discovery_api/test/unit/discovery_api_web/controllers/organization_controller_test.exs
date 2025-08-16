defmodule DiscoveryApiWeb.OrganizationControllerTest do
  use DiscoveryApiWeb.ConnCase
  import Mox
  alias DiscoveryApi.Schemas.Organizations
  alias DiscoveryApi.Schemas.Organizations.Organization

  @moduletag timeout: 5000

  setup :verify_on_exit!
  setup :set_mox_from_context

  @organization %Organization{
    id: "1234",
    name: "Org Name",
    title: "Org Title",
    description: "An Org",
    homepage: "http://homepage.org.com",
    logo_url: "http://logo.org.com"
  }

  setup do
    # Use :meck for Organizations module since it doesn't have dependency injection
    try do
      :meck.new(Organizations, [:passthrough])
    catch
      :error, {:already_started, _} -> :ok
    end

    on_exit(fn ->
      try do
        :meck.unload(Organizations)
      catch
        :error, _ -> :ok
      end
    end)

    :ok
  end

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

      :meck.expect(Organizations, :get_organization, fn "1234" -> {:ok, @organization} end)
      actual = conn |> get("/api/v1/organization/1234") |> json_response(200)

      assert expected == actual
    end

    test "returns 404 if organization does not exist", %{conn: conn} do
      :meck.expect(Organizations, :get_organization, fn "1234" -> {:error, "Does not exist"} end)
      actual = conn |> get("/api/v1/organization/1234") |> json_response(404)

      assert %{"message" => "Not Found"} = actual
    end
  end
end
