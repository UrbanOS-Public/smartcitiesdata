defmodule Transformers.Construct do
  def constructTransformation(transformations) do
    Enum.map(transformations, fn transformation ->
      Transformers.FunctionBuilder.build(transformation.type, transformation.parameters)
    end)
  end
end
