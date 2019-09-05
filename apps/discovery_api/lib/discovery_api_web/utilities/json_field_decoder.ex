defmodule DiscoveryApiWeb.Utilities.JsonFieldDecoder do
  @moduledoc """
  false
  """
  def decode_one_datum([], datum) do
    datum
  end

  def decode_one_datum([column | remaining_schema], datum) do
    downcased_column_name = String.downcase(column.name)

    cond do
      column.type == "json" and Map.has_key?(datum, downcased_column_name) ->
        decode_one_datum(
          remaining_schema,
          Map.put(datum, downcased_column_name, Jason.decode!(datum[downcased_column_name]))
        )

      true ->
        decode_one_datum(remaining_schema, datum)
    end
  end
end
