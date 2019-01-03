defmodule DiscoveryApi.Search.FacetFilterator do
  def filter_by_facets(datasets, facets) do
    datasets
    |> Enum.filter(&dataset_contains_all_facet_values?(&1, facets))
  end

  defp dataset_contains_all_facet_values?(dataset, facets) do
    Enum.all?(facets, &dataset_attributes_contain_all_facet_values?(&1, dataset))
  end

  defp dataset_attributes_contain_all_facet_values?({facet_name, facet_values}, dataset) do
    facet_name_as_atom = String.to_atom(facet_name)

    attribute_values =
      dataset
      |> Map.get(facet_name_as_atom)
      |> List.wrap()
      |> MapSet.new()

    facet_values
    |> MapSet.new()
    |> MapSet.subset?(attribute_values)
  end
end
