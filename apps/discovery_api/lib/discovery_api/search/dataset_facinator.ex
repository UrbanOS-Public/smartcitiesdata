defmodule DiscoveryApi.Search.DatasetFacinator do
  def get_facets(datasets) do
    %{
      organization: unique_organizations_with_count(datasets)
    }
  end

  defp unique_organizations_with_count(datasets) do
    datasets
    |> Enum.reduce(%{}, &record_organization_count/2)
  end

  defp record_organization_count(dataset, acc) do
    Map.update(acc, dataset[:organization], 1, &(&1 + 1))
  end
end
