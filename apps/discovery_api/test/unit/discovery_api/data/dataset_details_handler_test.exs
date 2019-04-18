defmodule DiscoveryApi.Data.DatasetDetailsHandlerTest do
  use ExUnit.Case
  use Placebo
  alias DiscoveryApi.Data.{DatasetDetailsHandler, Dataset}
  alias SmartCity.Organization
  alias SmartCity.TestDataGenerator, as: TDG

  test "maps a SmartCity.Dataset to a DiscoveryApi.Data.Dataset" do
    organization = TDG.create_organization(%{})
    dataset = TDG.create_dataset(%{technical: %{orgId: organization.id, sourceFormat: "csv"}})

    expected = create_expected_dataset(["CSV"], dataset, organization)

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

  test "maps fileTypes based on sourceFormat" do
    organization = TDG.create_organization(%{})
    dataset = TDG.create_dataset(%{technical: %{orgId: organization.id, sourceFormat: "gtfs"}})

    allow Organization.get(dataset.technical.orgId), return: {:ok, organization}
    allow Dataset.save(any()), return: {:ok, "OK"}

    DatasetDetailsHandler.process_dataset_details_event(dataset)

    discovery_dataset = capture(Dataset.save(any()), 1)

    assert discovery_dataset.fileTypes == ["JSON"]
  end

  defp create_expected_dataset(fileType, dataset, organization) do
    %Dataset{
      id: dataset.id,
      title: dataset.business.dataTitle,
      name: dataset.technical.dataName,
      systemName: dataset.technical.systemName,
      keywords: dataset.business.keywords,
      organization: organization.orgTitle,
      organizationDetails: organization,
      modified: dataset.business.modifiedDate,
      description: dataset.business.description,
      fileTypes: fileType,
      sourceFormat: dataset.technical.sourceFormat,
      sourceUrl: dataset.technical.sourceUrl,
      sourceType: dataset.technical.sourceType,
      private: false,
      contactName: dataset.business.contactName,
      contactEmail: dataset.business.contactEmail,
      license: dataset.business.license,
      rights: dataset.business.rights,
      homepage: dataset.business.homepage,
      spatial: dataset.business.spatial,
      temporal: dataset.business.temporal,
      publishFrequency: dataset.business.publishFrequency,
      conformsToUri: dataset.business.conformsToUri,
      describedByUrl: dataset.business.describedByUrl,
      describedByMimeType: dataset.business.describedByMimeType,
      parentDataset: dataset.business.parentDataset,
      issuedDate: dataset.business.issuedDate,
      language: dataset.business.language,
      referenceUrls: dataset.business.referenceUrls,
      categories: dataset.business.categories
    }
  end
end
