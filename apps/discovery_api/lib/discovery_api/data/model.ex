defmodule DiscoveryApi.Data.Model do
  @moduledoc """
  utilities to persist and load discovery data models
  """
  alias DiscoveryApi.Data.Persistence

  @behaviour Access

  @derive Jason.Encoder
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

  @spec get(any) :: any
  def get(id) do
    {:ok, model} = Brook.ViewState.get(DiscoveryApi.instance(), :models, id)

    model
    |> add_system_attributes()
  end

  def get_all() do
    {:ok, models} = Brook.ViewState.get_all(DiscoveryApi.instance(), :models)

    models
    |> Map.values()
    |> add_system_attributes()
  end

  def get_all(ids) do
    {:ok, models} = Brook.ViewState.get_all(DiscoveryApi.instance(), :models)

    models
    |> Enum.filter(fn {k, _v} -> k in ids end)
    |> Enum.map(fn {_k, v} -> v end)
    |> add_system_attributes()
  end

  def get_completeness({id, completeness}) do
    processed_completeness =
      case completeness do
        nil -> nil
        score -> score |> Jason.decode!() |> Map.get("completeness", nil)
      end

    {id, processed_completeness}
  end

  def get_last_updated_date(id) do
    ("forklift:last_insert_date:" <> id)
    |> Persistence.get()
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

  def remote?(model) do
    model.sourceType == "remote"
  end

  @impl Access
  def fetch(term, key), do: Map.fetch(term, key)

  @impl Access
  def get_and_update(data, key, func) do
    Map.get_and_update(data, key, func)
  end

  @impl Access
  def pop(data, key), do: Map.pop(data, key)

  defp add_system_attributes(nil), do: nil

  defp add_system_attributes(model) when is_map(model) do
    model
    |> List.wrap()
    |> add_system_attributes()
    |> List.first()
  end

  defp add_system_attributes(models) do
    redis_kv_results =
      Enum.map(models, &Map.get(&1, :id))
      |> get_all_keys()
      |> Persistence.get_many_with_keys()

    _new_models =
      Enum.map(models, fn model ->
        completeness = redis_kv_results["discovery-api:stats:#{model.id}"]
        downloads = redis_kv_results["smart_registry:downloads:count:#{model.id}"]
        queries = redis_kv_results["smart_registry:queries:count:#{model.id}"]
        last_updated_date = redis_kv_results["forklift:last_insert_date:#{model.id}"]

        model
        |> Map.put(:completeness, completeness)
        |> Map.put(:downloads, downloads)
        |> Map.put(:queries, queries)
        |> Map.put(:lastUpdatedDate, last_updated_date)
      end)
  end

  defp get_all_keys(ids) do
    ids
    |> Enum.map(fn id ->
      [
        "forklift:last_insert_date:#{id}",
        "smart_registry:downloads:count:#{id}",
        "smart_registry:queries:count:#{id}",
        "discovery-api:stats:#{id}"
      ]
    end)
    |> List.flatten()
  end
end
