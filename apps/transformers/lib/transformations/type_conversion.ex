defmodule Transformers.TypeConversion do
  @behaviour Transformation

  @impl Transformation
  def transform(payload, params) do

    with {:ok, field} <- fetchParameter(params, :field),
         {:ok, value} <- fetchPayloadValue(payload, field) do
      if(value == nil or value == "") do
        Map.put(payload, field, nil)
      end
    else
      {:error, reason} -> {:error, reason}
    end

  end

  defp fetchParameter(params, field_name) do
    case Map.fetch(params, field_name) do
      {:ok, field} -> {:ok, field}
      :error -> {:error, "Missing transformation parameter: #{field_name}"}
    end
  end

  defp fetchPayloadValue(payload, field_name) do
    case Map.fetch(payload, field_name) do
      {:ok, field} -> {:ok, field}
      :error -> {:error, "Missing field in payload: #{field_name}"}
    end
  end
end
