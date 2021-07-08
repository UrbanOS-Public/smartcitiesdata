defmodule DiscoveryApi.Data.MapperTest do
  use ExUnit.Case
  use Placebo
  alias DiscoveryApi.Data.{Mapper, Model, OrganizationDetails}
  alias SmartCity.TestDataGenerator, as: TDG
  import Checkov

  describe "to_data_model/2 hard overrides" do
    data_test "with #{inspect(overrides)} should default #{inspect(field)} to #{inspect(value)}" do
      dataset =
        overrides
        |> TDG.create_dataset()

      organization = DiscoveryApi.Test.Helper.create_schema_organization(%{})

      %Model{} = result = Mapper.to_data_model(dataset, organization)

      assert get_in(result, field) == value

      where([
        [:overrides, :field, :value],
        [%{technical: %{private: false}, business: %{license: nil}}, [:license], "http://opendefinition.org/licenses/cc-by/"],
        [%{technical: %{private: true}, business: %{license: nil}}, [:license], nil],
        [%{technical: %{private: false}, business: %{license: "overridden"}}, [:license], "overridden"],
        [%{technical: %{private: true}, business: %{license: "overridden"}}, [:license], "overridden"],
        [%{technical: %{private: false}}, [:accessLevel], "public"],
        [%{technical: %{private: true}}, [:accessLevel], "non-public"],
        [%{business: %{conformsToUri: nil}}, [:conformsToUri], "https://project-open-data.cio.gov/v1.1/schema/"],
        [%{business: %{conformsToUri: "overridden"}}, [:conformsToUri], "https://project-open-data.cio.gov/v1.1/schema/"],
        [%{technical: %{sourceFormat: "application/json"}}, [:fileTypes], ["JSON"]],
        [%{technical: %{sourceFormat: "application/gtfs+protobuf"}}, [:fileTypes], ["JSON"]],
        [%{technical: %{sourceFormat: "text/csv"}}, [:fileTypes], ["CSV"]]
      ])
    end
  end

  describe "to_organization_details/1" do
    test "returns the expected values" do
      organization = TDG.create_organization(%{})

      result = Mapper.to_organization_details(organization)

      assert result.id == organization.id
      assert result.orgName == organization.orgName
      assert result.orgTitle == organization.orgTitle
      assert result.description == organization.description
      assert result.logoUrl == organization.logoUrl
      assert result.homepage == organization.homepage
    end
  end
end
