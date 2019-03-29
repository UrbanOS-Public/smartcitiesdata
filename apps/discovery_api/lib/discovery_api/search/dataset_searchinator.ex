defmodule DiscoveryApi.Search.DatasetSearchinator do
  @moduledoc false
  alias DiscoveryApi.Data.Dataset

  def search(options \\ [query: ""]) do
    words =
      options[:query]
      |> String.split(" ")
      |> Enum.map(fn word -> String.downcase(word) end)

    result =
      Dataset.get_all()
      |> Enum.filter(fn dataset ->
        [dataset.title, dataset.description, dataset.organization]
        |> Enum.filter(fn property -> property != nil end)
        |> Enum.map(&String.downcase/1)
        |> Enum.any?(fn str -> String.contains?(str, words) end)
      end)

    {:ok, result}
  end
end
