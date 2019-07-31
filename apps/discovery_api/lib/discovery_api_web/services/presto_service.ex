defmodule DiscoveryApiWeb.Services.PrestoService do
  @moduledoc false
  def preview(dataset_system_name) do
    "select * from #{dataset_system_name} limit 50"
    |> Prestige.execute(rows_as_maps: true)
    |> Prestige.prefetch()
  end

  def preview_columns(dataset_system_name) do
    "show columns from #{dataset_system_name}"
    |> Prestige.execute()
    |> Prestige.prefetch()
    |> Enum.map(fn [column_name | _tail] -> column_name end)
  end

  @supported_statements [
    ~r/^\s*SELECT\s.*$/i,
    ~r/^\s*WITH\s.*$/i
  ]

  def supported?(statement) do
    cleaned = String.replace(statement, ~r/\s|;/, " ")

    Enum.any?(@supported_statements, &Regex.match?(&1, cleaned))
  end

  def get_affected_tables(statement) do
    query_plans = explain_query_plans(statement)

    write_tables_in_query = extract_write_tables(query_plans)
    read_tables_in_query = extract_read_tables(query_plans)

    {read_tables_in_query, write_tables_in_query}
  rescue
    Prestige.Error -> {[], []}
  end

  defp explain_query_plans(statement) do
    Prestige.execute("EXPLAIN (TYPE IO, FORMAT JSON) " <> statement, rows_as_maps: true)
    |> Stream.map(&Map.get(&1, "Query Plan"))
    |> Stream.map(&Jason.decode/1)
    |> Stream.filter(fn {ok, _} -> ok == :ok end)
    |> Stream.map(fn {_, plan} -> plan end)
  end

  defp extract_write_tables(query_plans) do
    query_plans
    |> Enum.map(&get_in(&1, ["outputTable", "schemaTable", "table"]))
    |> Enum.reject(&is_nil/1)
  end

  defp extract_read_tables(query_plans) do
    query_plans
    |> Enum.map(&get_in(&1, ["inputTableColumnInfos", Access.all(), "table"]))
    |> List.flatten()
    |> Enum.filter(&in_valid_schema?/1)
    |> Enum.map(&get_in(&1, ["schemaTable", "table"]))
  end

  defp in_valid_schema?(table_spec) do
    catalog = get_in(table_spec, ["catalog"])
    schema = get_in(table_spec, ["schemaTable", "schema"])

    catalog == "hive" && schema == "default"
  end
end
