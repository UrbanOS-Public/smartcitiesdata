defmodule DiscoveryApi.Search.FacetFilterator do
  def filter_by_facets(datasets, facets) do
    datasets
    |> Enum.filter(&all_facet_values_in_dataset?(&1, facets))
  end

  defp all_facet_values_in_dataset?(dataset, facets) do
    Enum.all?(facets, &all_facet_values_in_attribute_values?(&1, dataset))
  end

  defp all_facet_values_in_attribute_values?({facet_name, facet_values}, dataset) do
    attribute_value =
      [dataset[String.to_atom(facet_name)] || ""]
      |> List.flatten()

    MapSet.subset?(MapSet.new(facet_values), MapSet.new(attribute_value))
  end
end
