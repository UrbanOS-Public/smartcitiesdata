defmodule Estuary.Query.Select do
  @moduledoc false

  def select_table(value) do
    data =
      "SELECT #{translate_columns(value["columns"])}
      FROM #{value["table_name"]}
      #{translate_order(value["order_by"], value["order"])}
      LIMIT #{translate_limit(value["limit"])}"
      |> Prestige.execute(by_names: true)
      |> Prestige.prefetch()

    {:ok, data}
  rescue
    error -> {:error, error}
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
