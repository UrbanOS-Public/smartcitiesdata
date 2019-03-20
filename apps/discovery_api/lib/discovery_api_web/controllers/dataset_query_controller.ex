defmodule DiscoveryApiWeb.DatasetQueryController do
  @moduledoc false
  use DiscoveryApiWeb, :controller
  require Logger
  alias DiscoveryApi.Data.Retriever

  def query(conn, params) do
    query(conn, params, get_format(conn))
  end

  def query(conn, %{"dataset_id" => dataset_id} = params, "csv") do
    with {:ok, system_name} <- get_system_name(dataset_id),
         {:ok, column_names} <- get_column_names(system_name),
         {:ok, query} <- build_query(params, system_name) do
      query
      |> Prestige.execute(catalog: "hive", schema: "default")
      |> map_data_stream_for_csv(column_names)
      |> stream_data(conn, system_name, get_format(conn))
    else
      error -> handle_error(conn, error)
    end
  end

  def query(conn, %{"dataset_id" => dataset_id} = params, "json") do
    with {:ok, system_name} <- get_system_name(dataset_id),
         {:ok, query} <- build_query(params, system_name) do
      data =
        query
        |> Prestige.execute(catalog: "hive", schema: "default", rows_as_maps: true)
        |> Stream.map(&Jason.encode!/1)
        |> Stream.intersperse(",")

      [["["], data, ["]"]]
      |> Stream.concat()
      |> stream_data(conn, system_name, get_format(conn))
    else
      error -> handle_error(conn, error)
    end
  end

  defp handle_error(conn, {type, reason}) do
    case type do
      :bad_request ->
        Logger.error(reason)
        render_error(conn, 400, "Bad Request")

      :error ->
        Logger.error(reason)
        render_error(conn, 404, "Not Found")
    end
  end

  defp get_column_names(system_name) do
    "describe hive.default.#{system_name}"
    |> Prestige.execute()
    |> Prestige.prefetch()
    |> Enum.map(fn [col | _tail] -> col end)
    |> case do
      [] -> {:error, "Table #{system_name} not found"}
      names -> {:ok, names}
    end
  end

  defp get_system_name(dataset_id) do
    Retriever.get_dataset(dataset_id)
    |> case do
      nil -> {:error, "Dataset #{dataset_id} not found"}
      %{:system_name => system_name} -> {:ok, system_name}
    end
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
    |> validate_query()
  end

  defp validate_query(query) do
    [";", "/*", "*/", "--"]
    |> Enum.map(fn x -> String.contains?(query, x) end)
    |> Enum.any?(fn contained_string -> contained_string end)
    |> case do
      true -> {:bad_request, "Query contained an illegal character: [#{query}]"}
      false -> {:ok, query}
    end
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
end
