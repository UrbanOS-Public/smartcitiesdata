defmodule DiscoveryApiWeb.DatasetQueryController do
  @moduledoc false
  use DiscoveryApiWeb, :controller

  def query(conn, params) do
    query(conn, params, get_format(conn))
  end

  def query(conn, %{"dataset_id" => dataset_id} = params, "csv") do
    %{:system_name => system_name} = DiscoveryApi.Data.Retriever.get_dataset(dataset_id)
    where_clause = Map.get(params, "where", "") |> build_where()
    order_by_clause = Map.get(params, "orderBy", "") |> build_orderby()
    limit_clause = Map.get(params, "limit", "") |> build_limit()
    group_by_clause = Map.get(params, "groupBy", "") |> build_groupby()
    columns = Map.get(params, "columns", "*") |> String.replace(",", ", ")

    column_names =
      "describe hive.default.#{system_name}"
      |> Prestige.execute()
      |> Prestige.prefetch()
      |> Enum.map(fn [col | _tail] -> col end)

    ["SELECT", columns, "FROM #{system_name}", where_clause, order_by_clause, limit_clause, group_by_clause]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
    |> Prestige.execute(catalog: "hive", schema: "default")
    |> map_data_stream_for_csv(column_names)
    |> stream_data(conn, system_name)
  end

  defp build_where(""), do: nil

  defp build_where(clause) do
    "WHERE #{clause}"
  end

  defp build_orderby(""), do: nil

  defp build_orderby(clause) do
    "ORDER BY #{clause}"
  end

  defp build_limit(""), do: nil

  defp build_limit(clause) do
    "LIMIT #{clause}"
  end

  defp build_groupby(""), do: nil

  defp build_groupby(clause) do
    "GROUP BY #{clause}"
  end

  defp map_data_stream_for_csv(stream, table_headers) do
    [table_headers]
    |> Stream.concat(stream)
    |> CSV.encode(delimiter: "\n")
  end

  defp stream_data(stream, conn, system_name) do
    stream_data(stream, conn, system_name, get_format(conn))
  end

  defp stream_data(stream, conn, system_name, format) do
    conn =
      conn
      |> put_resp_content_type(MIME.type(format))
      |> put_resp_header("content-disposition", "attachment; filename=#{system_name}.#{format}")
      |> send_chunked(200)

    Enum.reduce_while(stream, conn, fn data, conn ->
      case chunk(conn, data) do
        {:ok, conn} -> {:cont, conn}
        {:error, :closed} -> {:halt, conn}
      end
    end)
  end
end
