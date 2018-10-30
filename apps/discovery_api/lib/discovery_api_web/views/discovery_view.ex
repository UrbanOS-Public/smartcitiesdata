defmodule DiscoveryApiWeb.DiscoveryView do
  use DiscoveryApiWeb, :view

  def render("fetch_dataset_summaries.json", %{datasets: datasets, sort: sort_by}) do
    transform_metadata(datasets, sort_by)
  end

  def render("fetch_dataset_detail.json", %{dataset: dataset}) do
    transform_dataset_detail(dataset)
  end

  defp transform_metadata(metadata, sort_by) do
    %{
      metadata: %{
        totalDatasets: 150,
        limit: 10,
        offest: 0
      },
      results: Enum.map(metadata, &transform_metadata_item/1) |> sort_metadata(sort_by)
    }
  end

  defp sort_metadata(metadata, sort_by) do
    case sort_by do
      "name_asc" -> Enum.sort_by(metadata, fn(map) -> String.downcase(map.systemName) end)
      "name_des" -> Enum.sort_by(metadata, fn(map) -> String.downcase(map.systemName) end, &>=/2)
      "last_mod" -> Enum.sort_by(metadata, fn(map) -> map.modifiedTime end, &>=/2)
    end
  end

  defp transform_metadata_item(metadata_item) do
      %{
        description: metadata_item["description"],
        fileTypes: ["csv"],
        id: metadata_item["id"],
        systemName: metadata_item["systemName"],
        title: metadata_item["displayName"],
        modifiedTime: metadata_item["modifiedTime"]
      }
  end

  defp transform_dataset_detail(feed_detail) do
    %{
      name: feed_detail["feedName"],
      description: feed_detail["description"],
      id: feed_detail["id"],
      tags: feed_detail["tags"],
      organization: %{
        id: feed_detail["category"]["id"],
        name: feed_detail["category"]["displayName"],
        description: feed_detail["category"]["description"],
        image: "https://www.cota.com/wp-content/uploads/2016/04/COSI-Image-414x236.jpg"
      }
    }
  end

end
