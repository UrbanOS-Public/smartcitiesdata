defmodule DiscoveryApi.Data.Retriever do
  @moduledoc false
  def get_datasets do
    DiscoveryApi.Data.Dataset.get_all()
  end

  def get_dataset(dataset_id) do
    DiscoveryApi.Data.Dataset.get(dataset_id)
  end
end
