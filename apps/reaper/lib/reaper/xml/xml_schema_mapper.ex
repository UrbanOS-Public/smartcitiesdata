defmodule Reaper.XmlSchemaMapper do
  import SweetXml

  def map(row, schema) do
    parsed_row = SweetXml.parse(row)

    schema
    |> Enum.map(fn %{name: key, selector: selector} ->
      {key, SweetXml.xpath(parsed_row, sigil_x(selector, 's'))}
    end)
    |> Enum.into(Map.new())
  end
end
