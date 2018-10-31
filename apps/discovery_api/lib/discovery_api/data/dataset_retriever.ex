defmodule DiscoveryApi.Data.Retriever do
  def get_datasets do
    with {:ok, datasets} <- Cachex.get(:dataset_cache, "datasets") do
      {:ok, datasets}
    else
      _ -> {:error, "Could not retrieve datasets"}
    end
  end
end
