defmodule DiscoveryApiWeb.Utilities.JsonFieldDecoder do
  @moduledoc """
  false
  """
  def ensure_decoded(data_stream, schemas) do
    Stream.map(data_stream, fn datum -> decode_one_datum(schemas, datum) end)
  end

  defp decode_one_datum([], datum) do
    datum
  end

  defp decode_one_datum([column | remaining_schema] = schemas, datum) do
    case column.type do
      "json" ->
        decode_one_datum(remaining_schema, Map.put(datum, column.name, Jason.decode!(datum[column.name])))

      _ ->
        decode_one_datum(remaining_schema, datum)
    end
  end
end
