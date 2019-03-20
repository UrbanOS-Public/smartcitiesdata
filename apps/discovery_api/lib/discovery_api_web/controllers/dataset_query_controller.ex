defmodule DiscoveryApiWeb.DatasetQueryController do
  @moduledoc false
  use DiscoveryApiWeb, :controller

  def query(conn, params) do
    query(conn, params, get_format(conn))
  end

  def query(conn, %{"dataset_id" => dataset_id} = params, "csv") do
    %{:system_name => system_name} = DiscoveryApi.Data.Retriever.get_dataset(dataset_id)

    column_names = get_column_names(system_name)

    params
    |> build_query(system_name)
    |> Prestige.execute(catalog: "hive", schema: "default")
    |> map_data_stream_for_csv(column_names)
    |> stream_data(conn, system_name)
  end

  defp get_column_names(system_name) do
    "describe hive.default.#{system_name}"
    |> Prestige.execute()
    |> Prestige.prefetch()
    |> Enum.map(fn [col | _tail] -> col end)
  end

  defp build_query(params, system_name) do
    columns = Map.get(params, "columns", "*")

    ["SELECT"]
    |> build_columns(columns)
    |> Enum.concat(["FROM #{system_name}"])
    |> add_clause("where", params)
    |> add_clause("orderBy", params)
    |> add_clause("limit", params)
    |> add_clause("groupBy", params)
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
  end

  defp add_clause(clauses, type, map) do
    value = Map.get(map, type, "")
    clauses ++ [build_clause(type, value)]
  end

  defp build_clause(_, ""), do: nil
  defp build_clause("where", value), do: "WHERE #{value}"
  defp build_clause("orderBy", value), do: "ORDER BY #{value}"
  defp build_clause("limit", value), do: "LIMIT #{value}"
  defp build_clause("groupBy", value), do: "GROUP BY #{value}"

  defp build_columns(clauses, columns) do
    cleaned_columns = columns |> String.replace(",", ", ")
    clauses ++ [cleaned_columns]
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
