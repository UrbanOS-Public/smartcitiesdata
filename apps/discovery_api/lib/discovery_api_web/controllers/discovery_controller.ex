defmodule DiscoveryApiWeb.DiscoveryController do
  use DiscoveryApiWeb, :controller

  def fetch_dataset_summaries(conn, _params) do
    try do
      {:ok, %HTTPoison.Response{body: body}} = HTTPoison.get("#{data_lake_url()}/v1/metadata/feed")
      IO.inspect(body)

      result =
        Poison.decode!(body)
        |> Enum.map(&transform_metadata/1)

      json(conn, result)
    rescue
      error -> handle_exception(conn, error)
    end
  end

  defp handle_exception(conn, error) do
    error |> IO.inspect
    json(conn |> put_status(:internal_server_error), %{ message: "There was a problem processing your request" })
  end

  defp transform_metadata(metadata) do
    %{
      description: metadata["description"],
      fileTypes: ["csv"],
      id: metadata["id"],
      systemName: metadata["systemName"],
      title: metadata["displayName"],
    }
  end

  defp data_lake_url do
    Application.get_env(:discovery_api, :data_lake_url)
  end
end
