defmodule DiscoveryApi.Search.DataModelSearchinator do
  @moduledoc false
  alias DiscoveryApi.Data.Model

  def search(query \\ "") do
    search_criteria = extract_search_criteria(query)

    Enum.filter(Model.get_all(), &satisfies_search_criteria?(&1, search_criteria))
  end

  defp extract_search_criteria(query) do
    query
    |> String.downcase()
    |> String.split(" ")
  end

  defp satisfies_search_criteria?(%Model{} = model, search_criteria) do
    [model.title, model.description, model.organization, model.keywords]
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&String.downcase/1)
    |> Enum.any?(&String.contains?(&1, search_criteria))
  end
end
