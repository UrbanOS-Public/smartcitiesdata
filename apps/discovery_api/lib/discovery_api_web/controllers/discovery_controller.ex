defmodule DiscoveryApiWeb.DiscoveryController do
  use DiscoveryApiWeb, :controller

  def fetch_dataset_summaries(conn, _params) do
    try do
      {:ok, %HTTPoison.Response{body: body}} =
        HTTPoison.get("#{data_lake_url()}/v1/metadata/feed")

      result =
        Poison.decode!(body)
        |> Enum.map(&transform_metadata/1)

      json(conn, result)
    rescue
      error -> handle_exception(conn, error)
    end
  end

  def fetch_dataset_detail(conn, params) do
    try do
      {:ok, %HTTPoison.Response{body: body}} =
        HTTPoison.get("#{data_lake_url()}/v1/feedmgr/feed/#{params["dataset_id"]}")

      result =
        Poison.decode!(body)
        |> transform_feed_detail

      json(conn, result)
    rescue
      error -> handle_exception(conn, error)
    end
  end

  defp handle_exception(conn, error) do
    error |> IO.inspect()

    json(conn |> put_status(:internal_server_error), %{
      message: "There was a problem processing your request"
    })
  end

  defp transform_metadata(metadata) do
    %{
      description: metadata["description"],
      fileTypes: ["csv"],
      id: metadata["id"],
      systemName: metadata["systemName"],
      title: metadata["displayName"]
    }
  end

  defp transform_feed_detail(feed_detail) do
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
