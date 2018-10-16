defmodule DiscoveryApiWeb.DiscoveryController do
  use DiscoveryApiWeb, :controller

  def fetch_dataset_summaries(conn, params) do
    retrieve_and_decode_data(conn, "#{data_lake_url()}/v1/metadata/feed", &transform_metadata/1)
  end

  def fetch_dataset_detail(conn, params) do
    retrieve_and_decode_data(conn, "#{data_lake_url()}/v1/feedmgr/feed/#{params["dataset_id"]}" , &transform_dataset_detail/1)
  end

  defp retrieve_and_decode_data(conn, url, transformer) do
    with {:ok, %HTTPoison.Response{body: body, status_code: 200}} <- HTTPoison.get(url),
         {:ok, decode} <- Poison.decode(body)
    do
      result = transformer.(decode)
      json(conn, result)
    else
      _ -> handle_exception(conn, "There was a problem processing your request")
    end
  end

  defp handle_exception(conn, error) do
    json(conn |> put_status(:internal_server_error), %{
      message: "There was a problem processing your request"
    })
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

  defp data_lake_url do
    Application.get_env(:discovery_api, :data_lake_url)
  end
end
