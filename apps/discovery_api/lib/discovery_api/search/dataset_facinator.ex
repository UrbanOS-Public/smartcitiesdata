defmodule DiscoveryApi.Search.DatasetFacinator do
  def get_facets(datasets) do
    %{
      organization: unique_organizations_with_count(datasets),
      tags: unique_tags_with_count(datasets)
    }
  end

  defp unique_organizations_with_count(datasets) do
    datasets
    |> Enum.reduce(%{}, &record_organization_count/2)
  end

  defp record_organization_count(dataset, acc) do
    Map.update(acc, dataset[:organization], 1, &(&1 + 1))
  end

  defp unique_tags_with_count(datasets) do
    datasets
    |> Enum.flat_map(fn x -> x[:tags] end)
    |> Enum.reduce(%{}, &record_tag_count/2)
  end

  defp record_tag_count(tag, acc) do
    Map.update(acc, tag, 1, &(&1 + 1))
  end
end
