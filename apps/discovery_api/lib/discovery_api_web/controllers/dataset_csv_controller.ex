require Logger
alias StreamingMetrics.Hostname

defmodule DiscoveryApiWeb.DatasetCSVController do
  use DiscoveryApiWeb, :controller
  alias DiscoveryApi.Data.Thrive

  @metric_collector Application.get_env(:discovery_api, :collector)

  def fetch_dataset_csv(conn, %{"dataset_id" => dataset_id} = params) do
    query_string = Map.get(params, "query", "")
    columns = Map.get(params, "columns", ["*"])

    with {:ok, metadata} <- fetch_dataset_metadata(dataset_id),
         {schema, table} <- extract_schema_and_table(metadata),
         {:ok, description} <- fetch_table_schema(schema, table),
         table_headers <- extract_table_headers(description),
         {:ok, stream} <-
           Thrive.stream_results(
             "select #{Enum.join(columns, ",")} from #{schema}.#{table} #{query_string}",
             1000
           ) do
      record_csv_download_count_metrics(dataset_id, table)

      stream
      |> Stream.map(&Tuple.to_list(&1))
      |> (fn stream -> Stream.concat([table_headers], stream) end).()
      |> CSV.encode(delimiter: "\n")
      |> Enum.into(
        conn
        |> put_resp_content_type("application/csv")
        |> put_resp_header("content-disposition", "attachment; filename=#{table}.csv")
        |> send_chunked(200)
      )
    else
      {:error, reason} -> DiscoveryApiWeb.Renderer.render_500(conn, parse_error_reason(reason))
    end
  end

  def parse_error_reason(reason) when is_binary(reason) do
    if reason |> String.downcase() |> String.contains?("hive") do
      "Something went wrong with your query."
    else
      reason
    end
  end

  def parse_error_reason(reason), do: reason

  defp fetch_dataset_metadata(dataset_id) do
    retrieve_and_decode_data("#{data_lake_url()}/v1/metadata/feed/#{dataset_id}")
  end

  defp fetch_table_schema(schema, table) do
    retrieve_and_decode_data("#{data_lake_url()}/v1/hive/schemas/#{schema}/tables/#{table}")
  end

  defp extract_schema_and_table(metadata) do
    %{
      "systemName" => table,
      "category" => %{
        "systemName" => schema
      }
    } = metadata

    {schema, table}
  end

  defp extract_table_headers(%{"fields" => fields}) do
    Enum.map(fields, &Map.get(&1, "name"))
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

  defp record_csv_download_count_metrics(dataset_id, table_name) do
    hostname = get_hostname()

    @metric_collector.count_metric(1, "downloaded_csvs", [
      {"PodHostname", "#{hostname}"},
      {"DatasetId", "#{dataset_id}"},
      {"Table", "#{table_name}"}
    ])
    |> List.wrap()
    |> @metric_collector.record_metrics("discovery_api")
    |> case do
      {:ok, _} -> {}
      {:error, reason} -> Logger.warn("Unable to write application metrics: #{inspect(reason)}")
    end
  end

  defp get_hostname(), do: Hostname.get()
end
