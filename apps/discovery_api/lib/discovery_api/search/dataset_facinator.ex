defmodule DiscoveryApi.Search.DatasetFacinator do
  def get_facets(datasets) do
    %{
      organization: unique_facets_with_count(datasets, :organization),
      tags: unique_facets_with_count(datasets, :tags)
    }
  end

  defp unique_facets_with_count(datasets, facet_type) do
    datasets
    |> extract_facets(facet_type)
    |> Enum.reduce(%{}, &count_facet_occurrences/2)
    |> Enum.map(fn {facet, count} -> %{name: facet, count: count} end)
  end

  defp extract_facets(datasets, facet_type) do
    datasets
    |> Enum.map(&Map.get(&1, facet_type))
    |> List.flatten()
  end

  defp count_facet_occurrences(facet, acc) do
    Map.update(acc, facet, 1, &(&1 + 1))
  end

end
