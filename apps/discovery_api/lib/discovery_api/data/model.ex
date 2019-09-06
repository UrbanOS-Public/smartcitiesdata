defmodule DiscoveryApi.Data.Model do
  @moduledoc """
  utilities to persist and load discovery data models
  """
  alias DiscoveryApi.Data.Persistence

  @behaviour Access
  defstruct [
    :accessLevel,
    :categories,
    :completeness,
    :conformsToUri,
    :contactEmail,
    :contactName,
    :describedByMimeType,
    :describedByUrl,
    :description,
    :downloads,
    :fileTypes,
    :homepage,
    :id,
    :issuedDate,
    :keywords,
    :language,
    :lastUpdatedDate,
    :license,
    :modifiedDate,
    :name,
    :organization,
    :organizationDetails,
    :parentDataset,
    :private,
    :publishFrequency,
    :queries,
    :referenceUrls,
    :rights,
    :schema,
    :sourceFormat,
    :sourceType,
    :sourceUrl,
    :spatial,
    :systemName,
    :temporal,
    :title
  ]

  @name_space "discovery-api:model:"

  def get_all() do
    (@name_space <> "*")
    |> Persistence.get_all()
    |> Enum.map(&struct_from_map/1)
  end

  def get_all(ids) do
    ids
    |> Enum.map(fn id -> @name_space <> id end)
    |> Persistence.get_many()
    |> Enum.map(&map_from_json/1)
    |> Enum.map(&struct_from_map/1)
  end

  def get(id) do
    (@name_space <> id)
    |> Persistence.get()
    |> map_from_json()
    |> struct_from_map()
    |> add_last_updated_date_to_struct()
    |> add_counts_to_struct()
    |> add_completeness_to_struct()
  end

  def get_last_updated_date(id) do
    ("forklift:last_insert_date:" <> id)
    |> Persistence.get()
  end

  def save(%__MODULE__{} = model) do
    model_to_save =
      model
      |> default_nil_field_to(:keywords, [])
      |> Map.from_struct()

    Persistence.persist(@name_space <> model.id, model_to_save)
  end

  defp map_from_json(nil), do: nil

  defp map_from_json(json) do
    Jason.decode!(json, keys: :atoms)
  end

  defp default_nil_field_to(model, field, default) do
    case Map.get(model, field) do
      nil -> Map.put(model, field, default)
      _ -> model
    end
  end

  defp struct_from_map(nil), do: nil

  defp struct_from_map(map) do
    struct(__MODULE__, map)
  end

  defp add_counts_to_struct(model) when model == nil, do: nil

  defp add_counts_to_struct(model) do
    values_to_add = Enum.into(get_count_maps(model.id), %{})
    struct(model, values_to_add)
  end

  defp add_last_updated_date_to_struct(nil), do: nil

  defp add_last_updated_date_to_struct(model) do
    struct(model, %{lastUpdatedDate: get_last_updated_date(model.id)})
  end

  defp add_completeness_to_struct(nil), do: nil

  defp add_completeness_to_struct(model) do
    struct(model, %{completeness: get_completeness(model.id)})
  end

  def get_completeness(dataset_id) do
    case Persistence.get("discovery-api:stats:" <> dataset_id) do
      nil -> nil
      score -> score |> Jason.decode!() |> Map.get("completeness", nil)
    end
  end

  # sobelow_skip ["DOS.StringToAtom"]
  def get_count_maps(dataset_id) do
    case Persistence.get_keys("smart_registry:*:count:" <> dataset_id) do
      [] ->
        %{}

      all_keys ->
        friendly_keys = Enum.map(all_keys, fn key -> String.to_atom(Enum.at(String.split(key, ":"), 1)) end)
        all_values = Persistence.get_many(all_keys)

        Enum.into(0..(Enum.count(friendly_keys) - 1), %{}, fn friendly_key ->
          {Enum.at(friendly_keys, friendly_key), Enum.at(all_values, friendly_key)}
        end)
    end
  end

  def fetch(term, key), do: Map.fetch(term, key)

  def get_and_update(data, key, func) do
    Map.get_and_update(data, key, func)
  end

  def pop(data, key), do: Map.pop(data, key)
end
