defmodule Transformers.TypeConversion do
  @behaviour Transformation

  @impl Transformation
  def transform(payload, params) do
    field = Map.get(params, :field)
    value = Map.get(payload, field)
    if(value == nil or value == "") do
      Map.put(payload, field, nil)
    end
  end
end
