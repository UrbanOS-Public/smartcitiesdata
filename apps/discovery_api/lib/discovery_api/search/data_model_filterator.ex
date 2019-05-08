defmodule DiscoveryApi.Search.DataModelFilterator do
  @moduledoc false
  alias DiscoveryApi.Data.Model

  def filter_by_facets(models, facets) do
    models
    |> Enum.filter(&data_model_contains_all_facet_values?(&1, facets))
  end

  defp data_model_contains_all_facet_values?(%Model{} = model, facets) do
    Enum.all?(facets, &data_model_attributes_contain_all_facet_values?(&1, model))
  end

  defp data_model_attributes_contain_all_facet_values?({facet_name, facet_values}, %Model{} = model) do
    attribute_values =
      model
      |> Map.get(facet_name)
      |> List.wrap()
      |> MapSet.new()

    facet_values
    |> MapSet.new()
    |> MapSet.subset?(attribute_values)
  end
end
