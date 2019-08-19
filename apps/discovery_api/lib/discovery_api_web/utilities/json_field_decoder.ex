defmodule JsonFieldDecoder do
  @moduledoc """
  false
  """
  def has_json_fields(schemas, data_streams) do
    for {data_value, value_index} <- Stream.with_index(data_streams) do
      for {value, index} <- Stream.with_index(data_value) do
        schemas
        |> Enum.at(index)
        |> Map.get(:type)
        |> decode_json_fields(value, index)
      end
    end
  end

  defp decode_json_fields("json", value, index) do
    Jason.decode!(value)
  end

  defp decode_json_fields(_, value, _) do
    value
  end
end
