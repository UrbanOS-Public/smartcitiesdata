defmodule Transformers.TypeConversion do
  @behaviour Transformation

  @impl Transformation
  def transform(payload, params) do

    with {:ok, field} <- Map.fetch(params, :field),
         {:ok, value} <- Map.fetch(payload, field) do
      if(value == nil or value == "") do
        Map.put(payload, field, nil)
      end
    else
      :error -> {:error, "Field to convert does not exist in message"}
    end
    
  end
end
