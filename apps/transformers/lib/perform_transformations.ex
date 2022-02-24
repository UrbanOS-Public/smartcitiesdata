defmodule Transformers.Perform do
  defp allResultItemsAreFunctions(result) do
    Enum.all?(result, fn item -> is_function(item) end)
  end

  defp executeOperations(operations, initial_payload) do
    Enum.reduce_while(operations, {:ok, initial_payload}, fn op, {:ok, acc_payload} ->
      case op.(acc_payload) do
        {:ok, result} ->
          {:cont, {:ok, result}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end

  def performTransformations(operations, initial_payload) do
    if(allResultItemsAreFunctions(operations)) do
      executeOperations(operations, initial_payload)
    else
      {:error, "Invalid list of functions passed to performTransformations"}
    end
  end
end
