defmodule DiscoveryApi.Data.MapperRaptorTest do
  @moduledoc """
  Test to verify the RaptorService mock works correctly in the mapper
  """

  use ExUnit.Case
  import Mox

  alias DiscoveryApi.Data.Mapper
  alias SmartCity.TestDataGenerator, as: TDG

  setup :verify_on_exit!

  setup do
    smart_city_org = TDG.create_organization(%{})
    # Convert to the expected organization struct type
    organization = %DiscoveryApi.Schemas.Organizations.Organization{
      id: smart_city_org.id,
      name: smart_city_org.orgName,
      title: smart_city_org.orgTitle,
      description: smart_city_org.description,
      homepage: smart_city_org.homepage,
      logo_url: smart_city_org.logoUrl
    }

    dataset = TDG.create_dataset(%{})

    %{organization: organization, dataset: dataset}
  end

  test "mapper can retrieve access groups without throwing exception", %{dataset: dataset, organization: organization} do
    # Mock RaptorService to return empty access groups instead of throwing an exception
    stub(RaptorServiceMock, :list_access_groups_by_dataset, fn _raptor_url, _dataset_id ->
      %{access_groups: []}
    end)

    # This should not throw the "Access groups cannot be retrieved for dataset" error
    # because we've mocked RaptorService to return empty access groups
    result = Mapper.to_data_model(dataset, organization)

    # The result should be successful (not an error)
    assert {:ok, _model} = result
  end
end
