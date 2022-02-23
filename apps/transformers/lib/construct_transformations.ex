defmodule Transformers.Construct do
  def constructTransformation(transformations) do
    Enum.map(transformations, fn transformation ->
      with {:ok, type} <- Map.fetch(transformation, :type),
           {:ok, parameters} <- Map.fetch(transformation, :parameters) do
        Transformers.FunctionBuilder.build(type, parameters)
      else
        :error -> {:error, "Map provided is not a valid transformation"}
      end
    end)
  end
end
