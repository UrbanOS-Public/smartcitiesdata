defmodule DiscoveryApi.Search.FacetFilterator do
  def filter_by_facets(datasets, facets) do
    datasets
    |> Enum.filter(&filter_dataset_using_facet_values(&1, facets))
  end

  defp filter_dataset_using_facet_values(dataset, facets) do
    Enum.all?(facets, &attribute_value_in_facet_values?(&1, dataset))
  end

  defp attribute_value_in_facet_values?({facet_name, facet_values}, dataset) do
    attribute_value =
      [dataset[String.to_atom(facet_name)] || ""]
      |> List.flatten()

    MapSet.subset?(MapSet.new(facet_values), MapSet.new(attribute_value))
  end
end
