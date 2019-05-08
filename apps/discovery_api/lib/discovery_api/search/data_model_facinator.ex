defmodule DiscoveryApi.Search.DataModelFacinator do
  @moduledoc false
  def extract_facets(models) do
    %{
      organization: unique_facets_with_count(models, :organization),
      keywords: unique_facets_with_count(models, :keywords)
    }
  end

  defp unique_facets_with_count(models, facet_type) do
    models
    |> extract_facet_values(facet_type)
    |> Enum.reduce(%{}, &count_facet_occurrences/2)
    |> Enum.map(fn {facet, count} -> %{name: facet, count: count} end)
  end

  defp extract_facet_values(models, facet_type) do
    models
    |> Enum.map(&Map.get(&1, facet_type))
    |> List.flatten()
  end

  defp count_facet_occurrences(facet, acc) do
    Map.update(acc, facet, 1, &(&1 + 1))
  end
end
