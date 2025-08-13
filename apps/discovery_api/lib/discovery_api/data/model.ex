defmodule DiscoveryApi.Data.Model do
  @moduledoc """
  utilities to persist and load discovery data models
  """

  # Allow configuring the persistence module for testing
  @persistence_impl Application.compile_env(:discovery_api, :persistence, DiscoveryApi.Data.Persistence)

  @instance_name DiscoveryApi.instance_name()

  @collection :models
  @downloads_key "smart_registry:downloads:count"
  @queries_key "smart_registry:queries:count"
  @stats_key "discovery-api:stats"

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
    :title,
    :accessGroups
  ]

  def new(data) do
    model = struct(DiscoveryApi.Data.Model, data)

    org_with_atom_keys =
      model.organizationDetails
      |> from_struct()
      |> Enum.map(&string_to_atom/1)
      |> Map.new()

    org_details = struct(DiscoveryApi.Data.OrganizationDetails, org_with_atom_keys)

    Map.put(model, :organizationDetails, org_details)
    |> Map.put(:schema, SmartCity.Helpers.to_atom_keys(model.schema))
  end

  defp string_to_atom({k, v}) when is_atom(k) do
    {k, v}
  end

  # sobelow_skip ["DOS.StringToAtom"]
  defp string_to_atom({k, v}) when is_binary(k) do
    {String.to_atom(k), v}
  end

  defp from_struct(%_type{} = data) do
    Map.from_struct(data)
  end

  defp from_struct(data), do: data

  @spec get(any) :: any
  def get(id) do
    {:ok, model} = Brook.ViewState.get(@instance_name, @collection, id)

    model
    |> ensure_struct()
    |> add_system_attributes()
  end

  def get_all() do
    {:ok, models} = Brook.ViewState.get_all(@instance_name, @collection)

    models
    |> Map.values()
    |> add_system_attributes()
  end

  def get_all(ids) do
    {:ok, models} = Brook.ViewState.get_all(@instance_name, @collection)

    models
    |> Enum.filter(fn {k, _v} -> k in ids end)
    |> Enum.map(fn {_k, v} -> v end)
    |> add_system_attributes()
  end

  def delete(id) do
    @persistence_impl.delete("#{@downloads_key}:#{id}")
    @persistence_impl.delete("#{@queries_key}:#{id}")

    Brook.ViewState.delete(@collection, id)
  end

  def get_completeness({id, completeness}) do
    processed_completeness =
      case completeness do
        nil -> nil
        score -> score |> Jason.decode!() |> Map.get("completeness", nil)
      end

    {id, processed_completeness}
  end

  # sobelow_skip ["DOS.StringToAtom"]
  def get_count_maps(dataset_id) do
    case @persistence_impl.get_keys("smart_registry:*:count:" <> dataset_id) do
      [] ->
        %{}

      all_keys ->
        friendly_keys = Enum.map(all_keys, fn key -> String.to_atom(Enum.at(String.split(key, ":"), 1)) end)
        all_values = @persistence_impl.get_many(all_keys)

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

  def to_table_info(model) do
    columns_from_schema = Enum.map(model.schema, &to_column_info/1)

    %{
      id: id_to_alphanumeric(model.id),
      description: model.id,
      alias: model.title,
      columns: columns_from_schema
    }
  end

  defp to_column_info(schema_field) do
    %{
      id: id_to_alphanumeric(schema_field.name),
      description: String.downcase(schema_field.name),
      dataType: schema_field.type
    }
  end

  def id_to_alphanumeric(id) do
    String.replace(id, ~r/[^a-zA-Z0-9_]/, "_") |> String.downcase()
  end

  defp add_system_attributes(nil), do: nil

  defp add_system_attributes(%__MODULE__{} = model) do
    model
    |> List.wrap()
    |> add_system_attributes()
    |> List.first()
  end

  defp add_system_attributes(models) do
    redis_kv_results =
      Enum.map(models, &Map.get(&1, :id))
      |> get_all_keys()
      |> @persistence_impl.get_many_with_keys()

    Enum.map(models, fn model ->
      completeness = redis_kv_results["#{@stats_key}:#{model.id}"]
      downloads = redis_kv_results["#{@downloads_key}:#{model.id}"]
      queries = redis_kv_results["#{@queries_key}:#{model.id}"]

      model
      |> ensure_struct()
      |> Map.put(:completeness, completeness)
      |> Map.put(:downloads, downloads)
      |> Map.put(:queries, queries)
    end)
  end

  defp get_all_keys(ids) do
    ids
    |> Enum.map(fn id ->
      [
        "#{@downloads_key}:#{id}",
        "#{@queries_key}:#{id}",
        "#{@stats_key}:#{id}"
      ]
    end)
    |> List.flatten()
  end

  defp ensure_struct(nil), do: nil
  defp ensure_struct(%__MODULE__{} = model), do: model
  defp ensure_struct(%{} = model), do: struct(__MODULE__, model)
end
