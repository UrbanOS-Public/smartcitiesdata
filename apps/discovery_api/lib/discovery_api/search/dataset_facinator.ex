defmodule DiscoveryApi.Search.DatasetFacinator do
  def get_facets(datasets) do
    %{
      organization: unique_facets_with_count(datasets, :organization),
      tags: unique_facets_with_count(datasets, :tags)
    }
  end

  defp unique_facets_with_count(datasets, facet_name) do
    datasets
    |> Enum.map(&Map.get(&1, facet_name))
    |> List.flatten()
    |> Enum.reduce(%{}, &record_facet_count/2)
  end

  defp record_facet_count(facet, acc) do
    Map.update(acc, facet, 1, &(&1 + 1))
  end
end
