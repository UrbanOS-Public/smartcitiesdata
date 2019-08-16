defmodule DiscoveryApi.Services.PrestoService do
  @moduledoc false
  @supported_statements [
    ~r/^\s*SELECT\s.*$/i,
    ~r/^\s*WITH\s.*$/i
  ]

  def preview(dataset_system_name, row_limit \\ 50) do
    "select * from #{dataset_system_name} limit #{row_limit}"
    |> Prestige.execute(rows_as_maps: true)
    |> Prestige.prefetch()
  end

  def preview_columns(dataset_system_name) do
    "show columns from #{dataset_system_name}"
    |> Prestige.execute()
    |> Prestige.prefetch()
    |> Enum.map(fn [column_name | _tail] -> column_name end)
  end

  def is_select_statement?(statement) do
    cleaned = String.replace(statement, ~r/\s|;/, " ")

    Enum.any?(@supported_statements, &Regex.match?(&1, cleaned))
  end

  def get_affected_tables(statement) do
    with {:ok, explanation} <- explain_statement(statement),
         {:ok, query_plan} <- extract_query_plan(explanation),
         [] <- extract_write_tables(query_plan),
         [] <- extract_system_tables(query_plan),
         [_ | _] = tables <- extract_read_tables(query_plan) do
      {:ok, tables}
    else
      _ -> {:error, "bad thing happened"}
    end
  end

  defp explain_statement(statement) do
    plan =
      Prestige.execute("EXPLAIN (TYPE IO, FORMAT JSON) " <> statement, rows_as_maps: true)
      |> Enum.into([])
      |> hd()
      |> Map.get("Query Plan")

    {:ok, plan}
  rescue
    Prestige.Error -> {:error, "bad thing happened"}
  end

  defp extract_query_plan(explanation) do
    Jason.decode(explanation)
  end

  defp extract_write_tables(query_plan) do
    query_plan
    |> get_in(["outputTable", "schemaTable", "table"])
    |> List.wrap()
    |> Enum.reject(&is_nil/1)
  end

  defp extract_system_tables(query_plan), do: extract_read_tables(query_plan, fn t -> not in_hive_schema?(t) end)
  defp extract_read_tables(query_plan), do: extract_read_tables(query_plan, &in_hive_schema?/1)

  defp extract_read_tables(query_plan, filter_function) do
    query_plan
    |> get_in(["inputTableColumnInfos", Access.all(), "table"])
    |> List.flatten()
    |> Enum.filter(filter_function)
    |> Enum.map(&get_in(&1, ["schemaTable", "table"]))
  end

  defp in_hive_schema?(table_spec) do
    catalog = get_in(table_spec, ["catalog"])
    schema = get_in(table_spec, ["schemaTable", "schema"])

    catalog == "hive" && schema == "default"
  end
end
