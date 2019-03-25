defmodule DiscoveryApi.Data.DatasetDetailsHandler do
  @moduledoc false
  alias DiscoveryApi.Data.Dataset, as: DiscoveryDataset

  def process_dataset_details_event(%SmartCity.Dataset{} = dataset) do
    DiscoveryDataset.save(%DiscoveryDataset{
      id: dataset.id,
      title: dataset.business.dataTitle,
      systemName: dataset.technical.systemName,
      keywords: dataset.business.keywords,
      organization: dataset.business.orgTitle,
      modified: dataset.business.modifiedDate,
      description: dataset.business.description,
      fileTypes: ["CSV"]
    })
  end
end
