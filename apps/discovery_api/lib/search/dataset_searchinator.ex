defmodule Data.DatasetSearchinator do
  def search(options \\ []) do
    words = String.split(options[:query], " ") |> Enum.map(fn word -> String.downcase(word) end)
    {:ok, datasets} = DiscoveryApi.Data.Retriever.get_datasets()

    Enum.filter(datasets, fn dataset ->
      [dataset[:title], dataset[:description]]
      |> Enum.filter(fn property -> property != nil end)
      |> Enum.map(&String.downcase/1)
      |> Enum.any?(fn str -> String.contains?(str, words) end)
    end)
  end
end
