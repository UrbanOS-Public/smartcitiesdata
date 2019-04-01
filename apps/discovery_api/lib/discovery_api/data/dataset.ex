defmodule DiscoveryApi.Data.Dataset do
  @moduledoc """
  dataset utilities to persist and load.
  """
  alias DiscoveryApi.Data.Persistence

  defstruct [
    :id,
    :title,
    :keywords,
    :organization,
    :orgId,
    :modified,
    :fileTypes,
    :description,
    :systemName,
    :sourceUrl,
    :sourceType
  ]

  @name_space "discovery-api:dataset:"

  def get_all() do
    (@name_space <> "*")
    |> Persistence.get_all()
    |> Enum.map(&struct_from_map/1)
  end

  def get(id) do
    (@name_space <> id)
    |> Persistence.get()
    |> struct_from_map()
  end

  def save(%__MODULE__{} = dataset) do
    dataset_to_save =
      dataset
      |> default_nil_field_to(:keywords, [])
      |> Map.from_struct()

    Persistence.persist(@name_space <> dataset.id, dataset_to_save)
  end

  defp default_nil_field_to(dataset, field, default) do
    case Map.get(dataset, field) do
      nil -> Map.put(dataset, field, default)
      _ -> dataset
    end
  end

  defp struct_from_map(nil), do: nil

  defp struct_from_map(map) do
    struct(__MODULE__, map)
  end
end
