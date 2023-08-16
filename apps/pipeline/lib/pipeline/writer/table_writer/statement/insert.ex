defmodule Pipeline.Writer.TableWriter.Statement.Insert do
  @moduledoc false

  require Logger

  def compose(config, data) do
    columns = config.schema

    columns_fragment =
      columns
      |> Enum.map(&Map.get(&1, :name))
      |> Enum.map(&to_string/1)
      |> Enum.map(&hyphen_to_underscore/1)
      |> Enum.map(&~s|"#{&1}"|)
      |> Enum.join(",")

    data_fragment =
      data
      |> Enum.map(&format_columns(columns, &1))
      |> Enum.map(&to_row_string/1)
      |> Enum.join(",")

    {:ok, ~s|insert into "#{config.table}" (#{columns_fragment}) values #{data_fragment}|}
  rescue
    e ->
      Logger.error("Unhandled Statement Builder error: #{inspect(e)}")
      {:error, e}
  end

  defp hyphen_to_underscore(column_name) do
    String.replace(column_name, "-", "_")
  end

  defp format_columns(columns, row) do
    Enum.map(columns, fn %{name: name} = column ->
      row
      |> Map.get(to_string(name))
      |> format_data(column)
    end)
  end

  defp format_data(nil, %{type: _}), do: "null"

  defp format_data("", %{type: "string"}), do: "''"

  defp format_data("", %{type: "json"}), do: "''"

  defp format_data("", %{type: _}), do: "null"

  defp format_data(value, %{type: type}) when type in ["string", "json"] do
    value
    |> to_string()
    |> escape_quote()
    |> wrap_with_quote()
  end

  defp format_data(value, %{type: "date"}) do
    "date(#{format_data(value, %{type: "timestamp"})})"
  end

  defp format_data(value, %{type: "timestamp"}) do
    date_format =
      cond do
        String.length(value) == 19 -> "'%Y-%m-%dT%H:%i:%S'"
        String.length(value) == 20 -> "'%Y-%m-%dT%H:%i:%SZ'"
        String.ends_with?(value, "Z") -> "'%Y-%m-%dT%H:%i:%S.%fZ'"
        true -> "'%Y-%m-%dT%H:%i:%S.%f'"
      end

    "date_parse('#{value}', #{date_format})"
  end

  defp format_data(value, %{type: "time"}), do: "'#{value}'"

  defp format_data(value, %{type: "integer"}) when is_binary(value) do
    value
    |> Integer.parse()
    |> elem(0)
  end

  defp format_data(value, %{type: "float"}) when is_binary(value) do
    value
    |> Float.parse()
    |> elem(0)
  end

  defp format_data(value, %{type: "map", subSchema: sub_schema}) do
    sub_schema
    |> format_columns(value)
    |> to_row_string()
  end

  defp format_data(values, %{type: "list", itemType: "map", subSchema: sub_schema}) do
    values
    |> Enum.map(fn value -> format_data(value, %{type: "map", subSchema: sub_schema}) end)
    |> to_array_string()
  end

  defp format_data(values, %{type: "list", itemType: item_type}) do
    values
    |> Enum.map(fn value -> format_data(value, %{type: item_type}) end)
    |> to_array_string()
  end

  defp format_data(value, _type) do
    value
  end

  defp to_row_string(values) do
    values
    |> Enum.join(",")
    |> wrap_with_row()
  end

  defp to_array_string(values) do
    values
    |> Enum.join(",")
    |> wrap_with_array()
  end

  defp escape_quote(value), do: String.replace(value, "'", "''")

  defp wrap_with_quote(value), do: "'#{value}'"
  defp wrap_with_row(value), do: "row(#{value})"
  defp wrap_with_array(value), do: "array[#{value}]"
end
