defmodule Transformers.Perform do
  alias Transformers.Utils

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
    if(Utils.allOperationsItemsAreFunctions(operations)) do
      executeOperations(operations, initial_payload)
    else
      {:error, "Invalid list of functions passed to performTransformations"}
    end
  end
end
