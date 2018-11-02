defmodule DiscoveryApiWeb.DatasetSearchView do
  use DiscoveryApiWeb, :view

  def render("search_dataset_summaries.json", %{datasets: datasets, sort: sort_by, offset: offset, limit: limit}) do
    paged_sorted_data =
      sort_datasets(datasets, sort_by)
      |> paginate(offset, limit)
    %{
      "metadata" =>
        %{
          "totalDatasets" => Enum.count(datasets),
          "limit" => limit,
          "offset" => offset
        },
      "results" => paged_sorted_data
    }
  end

    defp sort_datasets(datasets, sort_by) do
    case sort_by do
      "name_asc" -> Enum.sort_by(datasets, fn(map) -> String.downcase(map[:systemName]) end)
      "name_desc" -> Enum.sort_by(datasets, fn(map) -> String.downcase(map[:systemName]) end, &>=/2)
      "last_mod" -> Enum.sort_by(datasets, fn(map) -> map[:modifiedTime] end, &>=/2)
    end
  end

  defp paginate(datasets, offset, limit) do
    Enum.slice(datasets, offset, limit)
  end

end
