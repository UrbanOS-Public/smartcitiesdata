defmodule DiscoveryApi.Services.PrestoService do
  @moduledoc false
  @supported_statements [
    ~r/^\s*SELECT\s.*$/i,
    ~r/^\s*WITH\s.*$/i
  ]

  def preview(session, dataset_system_name, row_limit \\ 50) do
    session
    |> Prestige.query!("select * from #{dataset_system_name} limit #{row_limit}")
    |> Prestige.Result.as_maps()
  end

  def preview_columns(session, dataset_system_name) do
    session
    |> Prestige.query!("show columns from #{dataset_system_name}")
    |> Map.get(:rows)
    |> Enum.map(fn [column_name | _tail] -> column_name end)
  end

  def is_select_statement?(statement) do
    cleaned = String.replace(statement, ~r/\s|;/, " ")

    Enum.any?(@supported_statements, &Regex.match?(&1, cleaned))
  end

  def get_affected_tables(session, statement) do
    with {:ok, explanation} <- explain_statement(session, statement),
         {:ok, query_plan} <- extract_query_plan(explanation),
         [] <- extract_write_tables(query_plan),
         [] <- extract_system_tables(query_plan),
         [_ | _] = tables <- extract_read_tables(query_plan) do
      {:ok, tables}
    else
      _ -> {:error, "bad thing happened"}
    end
  end

  defp explain_statement(session, statement) do
    plan =
      Prestige.query!(session, "EXPLAIN (TYPE IO, FORMAT JSON) " <> statement)
      |> Prestige.Result.as_maps()
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
    |> Enum.map(&String.downcase(&1))
  end

  defp in_hive_schema?(table_spec) do
    catalog = get_in(table_spec, ["catalog"])
    schema = get_in(table_spec, ["schemaTable", "schema"])

    catalog == "hive" && schema == "default"
  end

  def get_column_names(session, system_name, nil), do: get_column_names(session, system_name)

  def get_column_names(session, system_name, columns_string) do
    case get_column_names(session, system_name) do
      {:ok, _names} -> {:ok, clean_columns(columns_string)}
      {_, error} -> {:error, error}
    end
  end

  def get_column_names(session, system_name) do
    session
    |> Prestige.query!("describe #{system_name}")
    |> Map.get(:rows)
    |> Enum.map(fn [col | _tail] -> col end)
    |> case do
      [] -> {:error, "Table #{system_name} not found"}
      names -> {:ok, names}
    end
  end

  def build_query(params, system_name) do
    column_string = Map.get(params, "columns", "*")

    ["SELECT"]
    |> build_columns(column_string)
    |> Enum.concat(["FROM #{system_name}"])
    |> add_clause("where", params)
    |> add_clause("groupBy", params)
    |> add_clause("orderBy", params)
    |> add_clause("limit", params)
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
    |> validate_query()
  end

  defp validate_query(query) do
    [";", "/*", "*/", "--"]
    |> Enum.map(fn x -> String.contains?(query, x) end)
    |> Enum.any?(fn contained_string -> contained_string end)
    |> case do
      true -> {:bad_request, "Query contained illegal character(s): [#{query}]"}
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

  defp build_columns(clauses, column_string) do
    cleaned_columns = column_string |> clean_columns() |> Enum.join(", ")
    clauses ++ [cleaned_columns]
  end

  defp clean_columns(column_string) do
    column_string
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
  end
end
