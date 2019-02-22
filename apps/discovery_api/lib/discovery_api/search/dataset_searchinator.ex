defmodule DiscoveryApi.Search.DatasetSearchinator do
  def search(options \\ [query: ""]) do
    words = String.split(options[:query], " ") |> Enum.map(fn word -> String.downcase(word) end)

    result =
      DiscoveryApi.Data.Retriever.get_datasets()
      |> Enum.filter(fn dataset ->
        [dataset.title, dataset.description]
        |> Enum.filter(fn property -> property != nil end)
        |> Enum.map(&String.downcase/1)
        |> Enum.any?(fn str -> String.contains?(str, words) end)
      end)

    {:ok, result}
  end
end
