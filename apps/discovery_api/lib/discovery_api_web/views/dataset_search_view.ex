defmodule DiscoveryApiWeb.DatasetSearchView do
  use DiscoveryApiWeb, :view

  def render("search_dataset_summaries.json", %{
        datasets: datasets,
        facets: facets,
        sort: sort_by,
        offset: offset,
        limit: limit
      }) do
    paged_sorted_data =
      sort_datasets(datasets, sort_by)
      |> paginate(offset, limit)
      |> Enum.map(&Map.from_struct/1)
      |> Enum.map(fn data -> Map.drop(data, [:__meta__]) end)

    %{
      "metadata" => %{
        "totalDatasets" => Enum.count(datasets),
        "facets" => facets,
        "limit" => limit,
        "offset" => offset
      },
      "results" => paged_sorted_data
    }
  end

  defp sort_datasets(datasets, sort_by) do
    case sort_by do
      "name_asc" ->
        Enum.sort_by(datasets, fn map -> String.downcase(map.title) end)

      "name_desc" ->
        Enum.sort_by(datasets, fn map -> String.downcase(map.title) end, &>=/2)

      "last_mod" ->
        Enum.sort_by(datasets, fn map -> map.modified end, &>=/2)
    end
  end

  defp paginate(datasets, offset, limit) do
    Enum.slice(datasets, offset, limit)
  end
end
