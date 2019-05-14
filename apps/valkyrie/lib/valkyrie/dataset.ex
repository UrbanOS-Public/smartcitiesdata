defmodule Valkyrie.Dataset do
  @moduledoc """
  Caches an internal view of SmartCity.Dataset
  """

  defstruct [:schema]

  @cache :dataset_cache

  @spec cache_name() :: :dataset_cache
  def cache_name() do
    @cache
  end

  @doc """
    Insert a dataset into the cache
  """
  @spec put(SmartCity.Dataset.t()) :: Valkyrie.Dataset.t()
  def put(%SmartCity.Dataset{id: id} = dataset) do
    struct = to_struct(dataset)
    Cachex.put(@cache, id, struct)

    struct
  end

  @doc """
    Retrieve a dataset from the cache
  """
  @spec get(String.t()) :: SmartCity.Dataset.t()
  def get(dataset_id) do
    case Cachex.get!(@cache, dataset_id) do
      nil -> sync_dataset(dataset_id)
      value -> value
    end
  end

  defp sync_dataset(dataset_id) do
    case SmartCity.Dataset.get(dataset_id) do
      {:ok, dataset} -> put(dataset)
      {:error, _error} -> nil
    end
  end

  defp to_struct(%SmartCity.Dataset{technical: %{schema: schema}} = _dataset) do
    %__MODULE__{schema: schema}
  end
end
