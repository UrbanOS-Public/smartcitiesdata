defmodule DiscoveryApiWeb.Utilities.JsonFieldDecoder do
  @moduledoc """
  false
  """
  def ensure_decoded(schemas, data_stream) do
    for datum <- data_stream do
      decode_one_datum(schemas, datum)
    end
  end

  defp decode_one_datum(schemas, datum) do
    if schemas == [] do
      datum
    else
      case hd(schemas).type do
        "json" ->
          decode_one_datum(tl(schemas), Map.put(datum, hd(schemas).name, Jason.decode!(datum[hd(schemas).name])))

        _ ->
          decode_one_datum(tl(schemas), datum)
      end
    end
  end
end
