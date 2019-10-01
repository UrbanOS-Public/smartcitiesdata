defmodule DiscoveryApi.RecommendationEngine do
  @moduledoc false

  alias DiscoveryApi.Data.Persistence

  @prefix "discovery_api:dataset_recommendations:"

  def save(%SmartCity.Dataset{id: id, technical: %{systemName: systemName, schema: schema}}) do
    Persistence.persist(@prefix <> id, %{id: id, systemName: systemName, schema: schema_mapper(schema)})
  end

  def get_recommendations(%SmartCity.Dataset{} = dataset_to_match) do
    schema_to_match = dataset_to_match.technical.schema |> schema_mapper() |> MapSet.new()

    get_all_view_state_items()
    |> find_recommendations(schema_to_match, dataset_to_match)
    |> map_results()
  end

  defp schema_mapper(schema) do
    Enum.map(schema, fn column ->
      %{name: column.name, type: column.type}
    end)
  end

  defp get_all_view_state_items() do
    Persistence.get_all(@prefix <> "*")
    |> Enum.map(&Jason.decode!(&1, keys: :atoms))
  end

  defp find_recommendations(all_view_state_items, schema_to_match, dataset_to_match) do
    Enum.filter(all_view_state_items, fn view_state ->
      this_schema = MapSet.new(view_state.schema)
      count_of_shared_columns = MapSet.intersection(schema_to_match, this_schema) |> MapSet.size()
      count_of_shared_columns >= 3 && view_state.id != dataset_to_match.id
    end)
  end

  defp map_results(results) do
    Enum.map(results, fn dataset ->
      %{id: dataset.id, systemName: dataset.systemName}
    end)
  end
end
