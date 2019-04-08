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
    :organizationDetails,
    :modified,
    :fileTypes,
    :description,
    :systemName,
    :sourceUrl,
    :sourceType,
    :lastUpdatedDate,
    :contactName,
    :contactEmail,
    :license,
    :rights,
    :homepage,
    :spatial,
    :temporal,
    :publishFrequency,
    :conformsToUri,
    :describedByUrl,
    :describedByMimeType,
    :parentDataset,
    :issuedDate,
    :language,
    :referenceUrls,
    :categories
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
    |> map_from_json()
    |> struct_from_map()
    |> add_last_updated_date_to_struct()
  end

  def get_last_updated_date(id) do
    ("forklift:last_insert_date:" <> id)
    |> Persistence.get()
  end

  def save(%__MODULE__{} = dataset) do
    dataset_to_save =
      dataset
      |> default_nil_field_to(:keywords, [])
      |> Map.from_struct()

    Persistence.persist(@name_space <> dataset.id, dataset_to_save)
  end

  defp map_from_json(nil), do: nil

  defp map_from_json(json) do
    Jason.decode!(json, keys: :atoms)
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

  defp add_last_updated_date_to_struct(nil), do: nil

  defp add_last_updated_date_to_struct(dataset) do
    struct(dataset, %{lastUpdatedDate: get_last_updated_date(dataset.id)})
  end
end
