defmodule Valkyrie.Dataset do
  @moduledoc """
  Caches an internal view of SmartCity.Dataset
  """

  defstruct [:schema]

  @cache :dataset_cache

  def cache_name() do
    @cache
  end

  def put(%SmartCity.Dataset{id: id} = dataset) do
    struct = to_struct(dataset)
    Cachex.put(@cache, id, struct)

    struct
  end

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
