defmodule Forklift.Statement do
  @moduledoc false
  require Logger

  def build(schema, data) do
    columns_fragment =
      schema.columns
      |> Enum.map(&Map.get(&1, :name))
      |> Enum.map(&to_string/1)
      |> Enum.map(&~s("#{&1}"))
      |> Enum.join(",")

    data_fragment =
      data
      |> Enum.map(&format_columns(schema.columns, &1))
      |> Enum.map(&to_row_string/1)
      |> Enum.join(",")

    ~s/insert into "#{schema.system_name}" (#{columns_fragment}) values #{data_fragment}/
  rescue
    e ->
      Logger.error("Unhandled Statement Builder error: #{inspect(e)}")
      {:error, inspect(e)}
  end

  defp format_columns(columns, row) do
    Enum.map(columns, fn %{name: name} = column ->
      row
      |> Map.get(String.to_atom(name))
      |> format_data(column)
    end)
  end

  defp format_data(nil, %{type: _}), do: "null"

  defp format_data("", %{type: "string"}), do: ~S|''|

  defp format_data("", %{type: _}), do: "null"

  defp format_data(value, %{type: "string"}) do
    value
    |> to_string()
    |> escape_quote()
    |> (&~s('#{&1}')).()
  end

  defp format_data(value, %{type: "date"}) do
    value
    |> to_string()
    |> (&~s(DATE '#{&1}')).()
  end

  defp format_data(value, %{type: "timestamp"}) do
    value
    |> to_string()
    |> (&~s|date_parse('#{&1}', '%Y-%m-%dT%H:%i:%S.%fZ')|).()
  end

  defp format_data(value, %{type: "time"}) do
    value
    |> to_string()
    |> (&~s|'#{&1}'|).()
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
    |> (&~s|row(#{&1})|).()
  end

  defp to_array_string(values) do
    values
    |> Enum.join(",")
    |> (&~s|array[#{&1}]|).()
  end

  defp escape_quote(value), do: String.replace(value, "'", "''")
end
