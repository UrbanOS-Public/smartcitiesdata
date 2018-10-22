defmodule DiscoveryApiWeb.DiscoveryView do
  use DiscoveryApiWeb, :view

  def render("fetch_dataset_summaries.json", %{datasets: datasets}) do
    transform_metadata(datasets)
  end

  def render("fetch_dataset_detail.json", %{dataset: dataset}) do
    transform_dataset_detail(dataset)
  end

  defp transform_metadata(metadata) do
    Enum.map(metadata, &transform_metadata_item/1)
  end

  defp transform_metadata_item(metadata_item) do
      %{
        description: metadata_item["description"],
        fileTypes: ["csv"],
        id: metadata_item["id"],
        systemName: metadata_item["systemName"],
        title: metadata_item["displayName"]
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
