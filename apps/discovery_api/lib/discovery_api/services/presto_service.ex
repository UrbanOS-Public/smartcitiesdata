defmodule DiscoveryApi.Services.PrestoService do
  require Logger
  @moduledoc false
  @supported_statements [
    ~r/^\s*SELECT\s.*$/i,
    ~r/^\s*WITH\s.*$/i
  ]

  def preview(session, dataset_system_name, row_limit \\ 50, schema) do
    case_sensitive_columns = case Enum.empty?(schema) do
      true -> "*"
      false -> Enum.map(schema, fn col ->
        case_sensitive_name = Map.get(col, :name)
        "#{String.downcase(case_sensitive_name)} as \"#{case_sensitive_name}\""
      end)
      |> Enum.join(", ")
    end
    session
    |> Prestige.query!("select #{case_sensitive_columns} from #{dataset_system_name} limit #{row_limit}")
    |> Prestige.Result.as_maps()
  end

  def preview_columns(session, dataset_system_name) do
    session
    |> Prestige.query!("show columns from #{dataset_system_name}")
    |> Map.get(:rows)
    |> Enum.map(fn [column_name | _tail] -> column_name end)
    |> remove_metadata_columns()
  end

  def is_select_statement?(statement) do
    cleaned = String.replace(statement, ~r/\s|;/, " ")

    Enum.any?(@supported_statements, &Regex.match?(&1, cleaned))
  end

  def get_affected_tables(session, statement) do
    with true <- allowed_query?(statement),
         {:ok, explanation} <- explain_statement(session, statement),
         {:ok, query_plan} <- extract_query_plan(explanation),
         [] <- extract_write_tables(query_plan),
         [] <- extract_system_tables(query_plan),
         [_ | _] = tables <- extract_read_tables(query_plan) do
      {:ok, tables}
    else
      {:sql_error, error} -> {:sql_error, error}
      error -> {:error, "Could not get affected tables: #{inspect(error)}"}
    end
  end

  defp allowed_query?(query) do
    String.contains?(query, "$path") == false
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
    error in [Prestige.BadRequestError, Prestige.Error] ->
      {:sql_error, sanitize_error(error.message, "Syntax Error")}

    error ->
      Logger.error("Error explaining statement: #{statement}")
      Logger.error("#{inspect(error)}")
      {:error, "Invalid Query"}
  end

  def sanitize_error("Invalid X-Presto-Prepared-Statement header: " <> error, type) do
    sanitize_error(error, type)
  end

  def sanitize_error(error, type) do
    Regex.named_captures(~r|^.*?(?<line>line \d*:\d*: )?(?<message>.*)|, error)
    |> Map.get("message")
    |> add_error_type(type)
    |> obscure_missing_tables()
  end

  defp add_error_type(error, type), do: "#{type}: #{error}"

  defp obscure_missing_tables(error) do
    if String.contains?(error, "does not exist") do
      "Bad Request"
    else
      error
    end
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
    |> remove_metadata_columns()
  end

  def build_query(params, system_name, columns) do
    column_string = Map.get(params, "columns", Enum.join(columns, ", "))

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
    [";", "/*", "*/", "--", "$path"]
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

  defp remove_metadata_columns({:error, _reason} = error) do
    error
  end

  defp remove_metadata_columns({:ok, columns}) do
    {:ok, remove_metadata_columns(columns)}
  end

  defp remove_metadata_columns(columns) do
    metadata_columns = ["_extraction_start_time", "_ingestion_id", "os_partition"]

    columns |> Enum.reject(fn column -> column in metadata_columns end)
  end
end
