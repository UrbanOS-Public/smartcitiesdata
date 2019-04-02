defmodule DiscoveryApi.Data.DatasetDetailsHandler do
  @moduledoc false
  alias DiscoveryApi.Data.Dataset, as: DiscoveryDataset
  alias SmartCity.Organization

  def process_dataset_details_event(%SmartCity.Dataset{} = dataset) do
    case Organization.get(dataset.technical.orgId) do
      {:ok, organization} ->
        DiscoveryDataset.save(%DiscoveryDataset{
          id: dataset.id,
          title: dataset.business.dataTitle,
          systemName: dataset.technical.systemName,
          keywords: dataset.business.keywords,
          organization: organization.orgTitle,
          organizationDetails: organization,
          modified: dataset.business.modifiedDate,
          description: dataset.business.description,
          fileTypes: ["CSV"],
          sourceType: dataset.technical.sourceType,
          sourceUrl: dataset.technical.sourceUrl
        })

      error ->
        error
    end
  end
end
