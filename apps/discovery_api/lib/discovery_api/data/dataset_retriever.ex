defmodule DiscoveryApi.Data.Retriever do
  def get_datasets do
    case Cachex.get(:dataset_cache, "datasets") do
      {:ok, datasets} when datasets != nil -> {:ok, datasets}
      _ -> {:error, "Could not retrieve datasets"}
    end
  end
end
