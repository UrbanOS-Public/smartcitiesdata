defmodule DiscoveryApi.Data.OrganizationTest do
  use ExUnit.Case
  use Placebo
  alias DiscoveryApi.Data.Organization

  @cache Organization.cache_name()

  setup do
    Cachex.clear(@cache)
    :ok
  end

  describe "organization" do
    test "fetches organization from organization by org id" do
      expected =
        {:ok,
         %{
           "id" => "1234",
           "orgName" => "Org Name",
           "orgTitle" => "Org Title",
           "description" => nil,
           "homepage" => nil,
           "logoUrl" => nil
         }}

      allow SmartCity.Organization.get("1234"), return: {:ok, expected}

      assert expected = OrganizationController.("1234")
    end

    test "returns error tuple when organization is not found" do
      expected = {:error, %SmartCity.Organization.NotFound{}}
      allow SmartCity.Organization.get("1234"), return: expected

      assert expected = Organization.get("1234")
    end

    test "fetches org from cache if loaded into cache" do
      expected =
        {:ok,
         %{
           "id" => "1234",
           "orgName" => "Org Name",
           "orgTitle" => "Org Title",
           "description" => nil,
           "homepage" => nil,
           "logoUrl" => nil
         }}

      allow Cachex.get(any(), "1234"), return: expected
      allow SmartCity.Organization.get(any()), return: :does_not_matter
      refute_called SmartCity.Organization.get(any())

      assert expected = Organization.get("1234")
    end
  end
end
