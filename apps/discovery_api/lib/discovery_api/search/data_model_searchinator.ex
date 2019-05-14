defmodule DiscoveryApi.Search.DataModelSearchinator do
  @moduledoc false
  alias DiscoveryApi.Data.Model

  def search(query \\ "") do
    Model.get_all()
    |> Enum.filter(&result?(&1, query))
  end

  defp result?(%Model{} = model, query) do
    search_criteria = String.downcase(query)

    [model.title, model.description, model.organization, model.keywords]
    |> Enum.reject(&is_nil/1)
    |> Enum.any?(&satisfies_search_criteria?(&1, search_criteria))
  end

  defp satisfies_search_criteria?(value, query) when is_list(value) do
    partial_match?(value, query) || exact_match?(value, query)
  end

  defp satisfies_search_criteria?(value, query) do
    split =
      value
      |> String.downcase()
      |> String.split()

    query
    |> String.split()
    |> Enum.all?(fn search_term -> search_term in split end)
  end

  defp partial_match?(value, query) do
    for keyword <- Enum.map(value, &String.downcase/1),
        search_term <- String.split(query) do
      keyword == search_term
    end
    |> Enum.any?()
  end

  defp exact_match?(value, query) do
    value
    |> Enum.map(&String.downcase/1)
    |> Enum.any?(fn keyword -> keyword == query end)
  end
end
