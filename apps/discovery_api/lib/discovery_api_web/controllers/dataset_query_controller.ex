require Logger
alias StreamingMetrics.Hostname

defmodule DiscoveryApiWeb.DatasetQueryController do
  use DiscoveryApiWeb, :controller

  import DiscoveryApiWeb.RenderError

  alias DiscoveryApi.Data.Thrive

  @metric_collector Application.get_env(:discovery_api, :collector)

  alias DiscoveryApiWeb.DatasetQueryService
  alias DiscoveryApiWeb.MetricsCollectorService

  @default_query ""
  @default_columns ["*"]
  @default_type "csv"
  @default_row_limit 10_000
  @default_limit_clause "LIMIT " <> Integer.to_string(@default_row_limit)

  @limit_regex ~r/LIMIT (?'limit'\d+)/i

  def fetch_preview(conn, %{"dataset_id" => dataset_id}) do
    query = "LIMIT 50"

    with {:ok, stream, %{table_headers: table_headers}} <-
           DatasetQueryService.get_thrive_stream(dataset_id, query: query) do
      return_obj = DatasetQueryService.map_data_stream_to_obj(stream, table_headers, dataset_id)
      json(conn, return_obj)
    else
      {:error, reason} -> render_error(conn, 500, parse_error_reason(reason))
    end
  end

  def fetch_full_csv(conn, %{"dataset_id" => dataset_id}) do
    with {:ok, stream, %{table: table, table_headers: table_headers}} <-
           DatasetQueryService.get_thrive_stream(dataset_id) do
      MetricsCollectorService.record_csv_download_count_metrics(dataset_id, table)

      stream
      |> DatasetQueryService.map_data_stream_for_csv(table_headers)
      |> return_csv(conn, table)
    else
      {:error, reason} -> render_error(conn, 500, parse_error_reason(reason))
    end
  end

  def fetch_query(conn, %{"dataset_id" => dataset_id} = params) do
    limit = Map.get(params, "limit", @default_row_limit)

    query_string =
      Map.get(params, "query", @default_query)
      |> set_limit(limit)
      |> String.split()
      |> Enum.join(" ")
      |> String.replace(";", "")

    columns = Map.get(params, "columns", @default_columns)
    return_type = Map.get(params, "type", @default_type)

    with {:ok, stream, metadata} <-
           DatasetQueryService.get_thrive_stream(dataset_id, query_string: query_string, columns: columns) do
      table_headers =
        case columns do
          ["*"] = _default_columns -> metadata.table_headers
          _specified_columns -> columns
        end

      MetricsCollectorService.record_query_metrics(dataset_id, metadata.table, return_type)

      case return_type do
        "json" ->
          return_obj = DatasetQueryService.map_data_stream_to_obj(stream, table_headers, dataset_id)
          json(conn, return_obj)

        "csv" ->
          stream
          |> DatasetQueryService.map_data_stream_for_csv(table_headers)
          |> return_csv(conn, metadata.table)

        _unsupported_type ->
          text(conn, "That type is not supported")
      end
    else
      {:error, reason} -> render_error(conn, 500, parse_error_reason(reason))
    end
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

  def parse_error_reason(reason) when is_binary(reason) do
    case Regex.match?(~r/\bhive\b/i, reason) do
      true -> "Something went wrong with your query."
      _ -> reason
    end
  end

  def parse_error_reason(reason), do: reason

  defp get_hostname(), do: Hostname.get()

  defp convert_int(int) when int == nil, do: nil

  defp convert_int(int) do
    {result, _} = Integer.parse(int)
    result
  end

  defp get_limit(query_string) do
    if Regex.match?(@limit_regex, query_string) do
      Regex.named_captures(@limit_regex, query_string)
      |> Map.get("limit")
      |> convert_int
    end
  end

  defp set_limit(query_string, limit) do
    query_string = Regex.replace(@limit_regex, query_string, "")

    case limit do
      nil -> "#{query_string} LIMIT #{@default_row_limit}"
      l when l > @default_row_limit -> "#{query_string} LIMIT #{limit}"
      _ -> "#{query_string} LIMIT #{limit}"
    end
  end
end
