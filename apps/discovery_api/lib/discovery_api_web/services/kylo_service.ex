defmodule DiscoveryApiWeb.KyloService do
  def fetch_dataset_metadata(dataset_id) do
    retrieve_and_decode_data("#{data_lake_url()}/v1/metadata/feed/#{dataset_id}")
  end

  def fetch_table_schema(schema, table) do
    retrieve_and_decode_data("#{data_lake_url()}/v1/hive/schemas/#{schema}/tables/#{table}")
  end

  defp retrieve_and_decode_data(url) do
    with {:ok, %HTTPoison.Response{body: body, status_code: 200}} <-
           HTTPoison.get(url, Authorization: "Basic #{data_lake_auth_string()}"),
         {:ok, decode} <- Poison.decode(body) do
      {:ok, decode}
    else
      {:error, message} -> {:error, message}
    end
  end

  defp data_lake_url do
    Application.get_env(:discovery_api, :data_lake_url)
  end

  defp data_lake_auth_string do
    Application.get_env(:discovery_api, :data_lake_auth_string)
  end
end
