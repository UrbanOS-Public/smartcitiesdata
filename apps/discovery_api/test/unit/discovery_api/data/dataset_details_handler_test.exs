defmodule DiscoveryApi.Data.DatasetDetailsHandlerTest do
  use ExUnit.Case
  use Placebo
  alias DiscoveryApi.Data.{DatasetDetailsHandler, Dataset, Organization}
  alias SmartCity.TestDataGenerator, as: TDG

  test "maps a SmartCity.Dataset to a DiscoveryApi.Data.Dataset" do
    organization = TDG.create_organization(%{})
    dataset = TDG.create_dataset(%{technical: %{orgId: organization.id}})

    expected = %Dataset{
      id: dataset.id,
      title: dataset.business.dataTitle,
      systemName: dataset.technical.systemName,
      keywords: dataset.business.keywords,
      organization: dataset.business.orgTitle,
      organizationDetails: organization,
      modified: dataset.business.modifiedDate,
      description: dataset.business.description,
      fileTypes: ["CSV"],
      sourceUrl: dataset.technical.sourceUrl,
      sourceType: dataset.technical.sourceType
    }

    allow Organization.get(dataset.technical.orgId), return: {:ok, organization}
    allow Dataset.save(any()), return: {:ok, "OK"}

    DatasetDetailsHandler.process_dataset_details_event(dataset)

    assert_called Dataset.save(expected)
  end

  test "returns error tuple when organization is not found" do
    organization = TDG.create_organization(%{})
    dataset = TDG.create_dataset(%{technical: %{orgId: organization.id}})

    allow Organization.get(dataset.technical.orgId), return: {:error, :generic_error}

    assert {:error, _} = DatasetDetailsHandler.process_dataset_details_event(dataset)
  end
end
