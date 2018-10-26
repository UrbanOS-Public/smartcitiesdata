defmodule DiscoveryApiWeb.DiscoveryController do
  use DiscoveryApiWeb, :controller

  def fetch_dataset_summaries(conn, _params) do
    case retrieve_and_decode_data("#{data_lake_url()}/v1/metadata/feed") do
      {:ok, result}    -> render(conn, :fetch_dataset_summaries, datasets: result)
      {:error, reason} -> render_500(conn, reason)
    end
  end

  def fetch_dataset_detail(conn, %{"dataset_id" => dataset_id}) do
    case retrieve_and_decode_data("#{data_lake_url()}/v1/feedmgr/feed/#{dataset_id}") do
      {:ok, result}    -> render(conn, :fetch_dataset_detail, dataset: result)
      {:error, reason} -> render_500(conn, reason)
    end
  end

  defp retrieve_and_decode_data(url) do
    with {:ok, %HTTPoison.Response{body: body, status_code: 200}} <- HTTPoison.get(url),
         {:ok, decode} <- Poison.decode(body)
    do
      {:ok, decode}
    else
      _ -> {:error, "There was a problem processing your request"}
    end
  end

  defp render_500(conn, reason) do
    conn
    |> put_status(:internal_server_error)
    |> render(DiscoveryApiWeb.ErrorView, :"500", message: reason)
  end

  defp data_lake_url do
    Application.get_env(:discovery_api, :data_lake_url)
  end
end
