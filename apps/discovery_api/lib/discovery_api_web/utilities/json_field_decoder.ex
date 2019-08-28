defmodule DiscoveryApiWeb.Utilities.JsonFieldDecoder do
  @moduledoc """
  false
  """
  def decode_one_datum([], datum) do
    datum
  end

  def decode_one_datum([column | remaining_schema], datum) do
    case column.type do
      "json" ->
        decode_one_datum(remaining_schema, Map.put(datum, column.name, Jason.decode!(datum[column.name])))

      _ ->
        decode_one_datum(remaining_schema, datum)
    end
  end
end
