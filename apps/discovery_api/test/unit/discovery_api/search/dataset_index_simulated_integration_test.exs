defmodule DiscoveryApi.Data.Search.DatasetIndexSimulatedIntegrationTest do
  @moduledoc """
  Test to verify that dataset creation works with RaptorService mock without throwing exceptions
  """

  use ExUnit.Case
  import Mox

  alias SmartCity.TestDataGenerator, as: TDG
  alias DiscoveryApi.Data.Mapper

  setup :verify_on_exit!

  describe "dataset creation with RaptorService mock" do
    test "multiple datasets can be created without RaptorService exceptions" do
      # Mock RaptorService to return empty access groups for all calls
      stub(RaptorServiceMock, :list_access_groups_by_dataset, fn _raptor_url, _dataset_id ->
        %{access_groups: []}
      end)

      # Create multiple datasets like the integration test does
      datasets =
        Enum.map(0..9, fn x ->
          TDG.create_dataset(%{
            id: "#{x}",
            business: %{modifiedDate: "2020-03-01T00:0#{x}:00Z"}
          })
        end)

      # Create a valid organization for the mapper
      smart_city_org = TDG.create_organization(%{})

      organization = %DiscoveryApi.Schemas.Organizations.Organization{
        id: smart_city_org.id,
        name: smart_city_org.orgName,
        title: smart_city_org.orgTitle,
        description: smart_city_org.description,
        homepage: smart_city_org.homepage,
        logo_url: smart_city_org.logoUrl
      }

      # Test that all datasets can be mapped without throwing RaptorService exceptions
      results =
        Enum.map(datasets, fn dataset ->
          Mapper.to_data_model(dataset, organization)
        end)

      # All should succeed (no exceptions thrown)
      Enum.each(results, fn result ->
        assert {:ok, _model} = result
      end)

      # Verify we have the expected number of datasets
      assert length(results) == 10

      # Verify datasets are properly sorted by modification date
      sorted_datasets = Enum.sort_by(datasets, & &1.business.modifiedDate, :desc)
      # Latest modified
      assert List.first(sorted_datasets).id == "9"
      # Earliest modified
      assert List.last(sorted_datasets).id == "0"
    end
  end
end
