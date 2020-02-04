defmodule Estuary.Query.Select do
  @moduledoc false

  def create_select_statement(value) do
    "SELECT #{translate_columns(value["columns"])}
      FROM #{check_table_name(value["table_name"])}
      #{translate_condition(value["conditions"], value["condition_type"])}
      #{translate_order(value["order_by"], value["order"])}
      LIMIT #{translate_limit(value["limit"])}"
  rescue
    error -> error
  end

  defp translate_columns(columns) do
    case !is_nil(columns) do
      true ->
        columns
        |> Enum.reject(&(byte_size(&1) == 0))
        |> Enum.map_join(", ", & &1)

      _ ->
        "*"
    end
  end

  defp translate_condition(conditions, condition_type) do
    type = check_condition_type(condition_type)

    case !is_nil(conditions) do
      true ->
        "WHERE
        #{
          conditions
          |> Enum.reject(&(byte_size(&1) == 0))
          |> Enum.map_join("#{type} ", & &1)
        }"

      _ ->
        ""
    end
  end

  defp check_condition_type(condition_type) do
    case !is_nil(condition_type) and byte_size(condition_type) != 0 and
           (String.upcase(condition_type) == "AND" or String.upcase(condition_type) == "OR") do
      true -> " #{condition_type}"
      _ -> ""
    end
  end

  defp check_table_name(table_name) do
    case !is_nil(table_name) and byte_size(table_name) != 0 do
      true -> table_name
      _ -> raise "Table name missing"
    end
  end

  defp translate_order(order_by, order) do
    if !is_nil(order_by) and byte_size(order_by) != 0 do
      "ORDER BY #{order_by} #{translate_order(order)}"
    end
  end

  defp translate_order(order) do
    case order == "DESC" do
      true -> "DESC"
      _ -> "ASC"
    end
  end

  defp translate_limit(limit) do
    case is_integer(limit) do
      true -> limit
      _ -> "ALL"
    end
  end
end
