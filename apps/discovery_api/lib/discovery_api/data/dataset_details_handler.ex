defmodule DiscoveryApi.Data.DatasetDetailsHandler do
  alias DiscoveryApi.Data.Dataset

  def process_dataset_details_event(event) do
    business = map_or_nil(event["business"])
    operational = map_or_nil(event["operational"])

    Dataset.save(%Dataset{
      id: event["id"],
      title: business["title"],
      keywords: business["keywords"],
      organization: business["publisher"],
      modified: business["modified"],
      description: business["description"],
      fileTypes: operational["fileTypes"]
    })
  end

  defp map_or_nil(value) when is_map(value), do: value
  defp map_or_nil(_value), do: nil
end
