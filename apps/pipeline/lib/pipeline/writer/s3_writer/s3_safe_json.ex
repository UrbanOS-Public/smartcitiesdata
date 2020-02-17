defmodule Pipeline.Writer.S3Writer.S3SafeJson do
  @moduledoc false
  def build(record, schema) do
    format_columns(schema, record)
  end

  defp format_columns(columns, row) do
    Enum.map(columns, fn %{name: name} = column ->
      data =
        row
        |> Map.get(to_string(name))
        |> format_data(column)

      {name, data}
    end)
    |> Enum.into(%{})
  end

  defp format_data(nil, _column), do: nil

  defp format_data("", %{type: type}) when type in ["date", "timestamp"], do: nil

  defp format_data(value, %{type: "date"}) do
    Timex.parse!(value, "{ISO:Extended}") |> Timex.format!("{ISOdate}")
  end

  defp format_data(value, %{type: "timestamp"}) do
    Timex.parse!(value, "{ISO:Extended}") |> Timex.format!("{ISOdate} {h24}:{m}:{s}")
  end

  defp format_data(value, %{type: "map", subSchema: sub_schema}) do
    sub_schema
    |> format_columns(value)
  end

  defp format_data(values, %{type: "list", itemType: "map", subSchema: sub_schema}) do
    values
    |> Enum.map(fn value -> format_data(value, %{type: "map", subSchema: sub_schema}) end)
  end

  defp format_data(values, %{type: "list", itemType: item_type}) do
    values
    |> Enum.map(fn value -> format_data(value, %{type: item_type}) end)
  end

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

  defp format_data(value, _column) do
    value
  end
end
