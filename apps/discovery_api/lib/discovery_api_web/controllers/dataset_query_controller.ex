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

  @preview_limit 50

  def fetch_preview(conn, %{"dataset_id" => dataset_id}) do
    query = set_limit("", @preview_limit)

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
      |> clean_query()

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

  defp set_limit(query_string, limit) do
    query_string = Regex.replace(~r/LIMIT (?'limit'\d+)/i, query_string, "")

    limit =
      if limit && limit < @default_row_limit do
        limit
      else
        @default_row_limit
      end

    "#{query_string} LIMIT #{limit}"
  end

  defp clean_query(query_string) do
    query_string
    |> String.split()
    |> Enum.join(" ")
    |> String.replace(";", "")
  end
end
