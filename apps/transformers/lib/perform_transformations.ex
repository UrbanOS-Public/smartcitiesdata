defmodule Transformers.Perform do
  def performTransformations(opsList, initial_payload) do
    Enum.reduce_while(opsList, {:ok, initial_payload}, fn op, {:ok, acc_payload} ->
      case op.(acc_payload) do
        {:ok, result} ->
          {:cont, {:ok, result}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end
end
