defmodule Transformers.Construct do
  def constructTransformation(transformations) do
    Enum.map(transformations, fn transformation ->
      case Map.fetch(transformation, :type) do
        {:ok, type} -> Transformers.FunctionBuilder.build(type, transformation.parameters)
        :error -> {:error, "Map provided is not a valid transformation"}
      end
    end)
  end
end
