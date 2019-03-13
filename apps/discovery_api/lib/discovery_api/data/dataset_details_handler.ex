defmodule DiscoveryApi.Data.DatasetDetailsHandler do
  @moduledoc false
  alias DiscoveryApi.Data.Dataset

  def process_dataset_details_event(registry_message) do
    Dataset.save(%Dataset{
      id: registry_message.id,
      title: registry_message.business.dataTitle,
      keywords: registry_message.business.keywords,
      organization: registry_message.business.orgTitle,
      modified: registry_message.business.modifiedDate,
      description: registry_message.business.description,
      fileTypes: ["CSV"]
    })
  end
end
