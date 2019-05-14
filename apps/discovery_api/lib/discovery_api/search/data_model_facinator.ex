defmodule DiscoveryApi.Search.DataModelFacinator do
  @moduledoc false

  def extract_facets([] = _models, selected_facets) do
    default_values = %{organization: [], keywords: []}

    Enum.into(selected_facets, default_values, fn {name, values} ->
      {name, Enum.map(values, &facet_map(&1, 0))}
    end)
  end

  def extract_facets(models, _selected_facets) do
    %{
      organization: unique_facets_with_count(models, :organization),
      keywords: unique_facets_with_count(models, :keywords)
    }
  end

  defp unique_facets_with_count(models, facet_type) do
    models
    |> extract_facet_values(facet_type)
    |> Enum.reduce(%{}, &count_facet_occurrences/2)
    |> Enum.map(&facet_map/1)
  end

  defp extract_facet_values(models, facet_type) do
    models
    |> Enum.map(&Map.get(&1, facet_type))
    |> List.flatten()
  end

  defp count_facet_occurrences(facet, acc) do
    Map.update(acc, facet, 1, &(&1 + 1))
  end

  defp facet_map({name, count}), do: facet_map(name, count)

  defp facet_map(name, count) do
    %{name: name, count: count}
  end
end
