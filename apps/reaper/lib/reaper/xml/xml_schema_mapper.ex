defmodule Reaper.XmlSchemaMapper do
  import SweetXml

  def map(row, schema) do
    row
    |> SweetXml.parse()
    |> handle_schema(schema)
  end

  defp handle_schema(row, schema) do
    schema
    |> Enum.map(&handle_type(row, &1))
    |> Enum.into(Map.new())
  end

  defp handle_type(row, %{type: "map", name: key, subSchema: sub_schema}) do
    {key, handle_schema(row, sub_schema)}
  end

  defp handle_type(row, %{type: "list", name: key, itemType: "map", selector: selector, subSchema: sub_schema}) do
    items = SweetXml.xpath(row, sigil_x(selector, 'le'))

    {key, Enum.map(items, &handle_schema(&1, sub_schema))}
  end

  defp handle_type(row, %{type: "list", name: key, selector: selector}) do
    {key, SweetXml.xpath(row, sigil_x(selector, 'ls'))}
  end

  defp handle_type(row, %{name: key, selector: selector}) do
    {key, SweetXml.xpath(row, sigil_x(selector, 's'))}
  end
end
