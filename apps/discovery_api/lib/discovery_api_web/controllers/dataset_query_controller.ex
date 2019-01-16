require Logger
alias StreamingMetrics.Hostname

defmodule DiscoveryApiWeb.DatasetQueryController do
  use DiscoveryApiWeb, :controller

  alias DiscoveryApi.Data.Thrive

  @metric_collector Application.get_env(:discovery_api, :collector)

  @default_query ""
  @default_columns ["*"]
  @default_type "csv"

  def fetch_preview(conn, %{"dataset_id" => dataset_id}) do
    query = "LIMIT 50"

    with {:ok, stream, %{table_headers: table_headers}} <- get_thrive_stream(dataset_id, query: query) do
      return_obj =
        stream
        |> map_data_stream_to_obj(table_headers, dataset_id)

      json(conn, return_obj)
    else
      {:error, reason} -> render_error(conn, 500, parse_error_reason(reason))
    end
  end

  def fetch_full_csv(conn, %{"dataset_id" => dataset_id}) do
    with {:ok, stream, %{table: table, table_headers: table_headers}} <- get_thrive_stream(dataset_id) do
      record_csv_download_count_metrics(dataset_id, table)

      stream
      |> map_data_stream_for_csv(table_headers)
      |> return_csv(conn, table)
    else
      {:error, reason} -> render_error(conn, 500, parse_error_reason(reason))
    end
  end

  def fetch_query(conn, %{"dataset_id" => dataset_id} = params) do
    query_string = Map.get(params, "query", @default_query)
    columns = Map.get(params, "columns", @default_columns)
    return_type = Map.get(params, "type", @default_type)

    with {:ok, stream, metadata} <- get_thrive_stream(dataset_id, query_string: query_string, columns: columns) do
      table_headers =
        case columns do
          ["*"] = _default_columns -> metadata.table_headers
          _specified_columns -> columns
        end

      case return_type do
        "json" ->
          return_obj =
            stream
            |> map_data_stream_to_obj(table_headers, dataset_id)

          json(conn, return_obj)

        "csv" ->
          stream
          |> map_data_stream_for_csv(table_headers)
          |> return_csv(conn, metadata.table)

        _unsupported_type ->
          text(conn, "That type is not supported")
      end
    else
      {:error, reason} -> render_error(conn, 500, parse_error_reason(reason))
    end
  end

  def get_thrive_stream(dataset_id, opts \\ []) do
    query_string = Keyword.get(opts, :query_string, "")
    columns = Keyword.get(opts, :columns, ["*"])

    with {:ok, table, schema, table_headers} <- get_table_and_headers(dataset_id),
         hive_query <- "select #{Enum.join(columns, ",")} from #{schema}.#{table} #{query_string}",
         chunk_size <- 1000,
         {:ok, stream} <- Thrive.stream_results(hive_query, chunk_size) do
      {:ok, stream, %{table: table, table_headers: table_headers}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def map_data_stream_to_obj(stream, table_headers, dataset_id) do
    stream
    |> Stream.map(&Tuple.to_list(&1))
    |> Stream.map(&Enum.zip(table_headers, &1))
    |> Stream.map(&Enum.reduce(&1, %{}, fn {key, value}, map -> Map.put(map, key, value) end))
    |> Enum.to_list()
    |> (fn data ->
          %{
            content: %{
              id: dataset_id,
              columns: table_headers,
              data: data
            }
          }
        end).()
  end

  def map_data_stream_for_csv(stream, table_headers) do
    stream
    |> Stream.map(&Tuple.to_list(&1))
    |> (fn stream -> Stream.concat([table_headers], stream) end).()
    |> CSV.encode(delimiter: "\n")
  end

  def return_csv(stream, conn, table) do
    conn =
      conn
      |> put_resp_content_type("application/csv")
      |> put_resp_header("content-disposition", "attachment; filename=#{table}.csv")
      |> send_chunked(200)

    Enum.reduce_while(stream, conn, fn data, conn ->
      case chunk(conn, data) do
        {:ok, conn} -> {:cont, conn}
        {:error, :closed} -> {:halt, conn}
      end
    end)
  end

  def get_table_and_headers(dataset_id) do
    with {:ok, metadata} <- fetch_dataset_metadata(dataset_id),
         {schema, table} <- extract_schema_and_table(metadata),
         {:ok, description} <- fetch_table_schema(schema, table),
         table_headers <- extract_table_headers(description) do
      {:ok, table, schema, table_headers}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def parse_error_reason(reason) when is_binary(reason) do
    case Regex.match?(~r/\bhive\b/i, reason) do
      true -> "Something went wrong with your query."
      _ -> reason
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
