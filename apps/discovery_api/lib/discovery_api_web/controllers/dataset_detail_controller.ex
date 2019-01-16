defmodule DiscoveryApiWeb.DatasetDetailController do
  use DiscoveryApiWeb, :controller

  def fetch_dataset_detail(conn, %{"dataset_id" => dataset_id}) do
    case retrieve_and_decode_data("#{data_lake_url()}/v1/feedmgr/feeds/#{dataset_id}") do
      {:ok, result} -> render(conn, :fetch_dataset_detail, dataset: result)
      {:error, reason} -> render_error(conn, 500, reason)
    end
  end

  defp retrieve_and_decode_data(url) do
    with {:ok, %HTTPoison.Response{body: body, status_code: 200}} <-
           HTTPoison.get(url, Authorization: "Basic #{data_lake_auth_string()}"),
         {:ok, decode} <- Poison.decode(body) do
      {:ok, decode}
    else
      _ -> {:error, "There was a problem processing your request"}
    end
  end

  defp data_lake_url do
    Application.get_env(:discovery_api, :data_lake_url)
  end

  defp data_lake_auth_string do
    Application.get_env(:discovery_api, :data_lake_auth_string)
  end
end
