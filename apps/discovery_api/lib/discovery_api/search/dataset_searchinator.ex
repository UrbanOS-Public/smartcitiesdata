defmodule DiscoveryApi.Search.DatasetSearchinator do
  @moduledoc false
  alias DiscoveryApi.Data.Dataset

  def search(query \\ "") do
    search_criteria = extract_search_criteria(query)

    Enum.filter(Dataset.get_all(), &satisfies_search_criteria?(&1, search_criteria))
  end

  defp extract_search_criteria(query) do
    query
    |> String.downcase()
    |> String.split(" ")
  end

  defp satisfies_search_criteria?(dataset, search_criteria) do
    [dataset.title, dataset.description, dataset.organization, dataset.keywords]
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&String.downcase/1)
    |> Enum.any?(&String.contains?(&1, search_criteria))
  end
end
