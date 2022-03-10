defmodule Transformers do
  alias Transformers.OperationUtils

  def construct(transformations) do
    Enum.map(transformations, fn transformation ->
      with {:ok, type} <- Map.fetch(transformation, :type),
           {:ok, parameters} <- Map.fetch(transformation, :parameters) do
        Transformers.OperationBuilder.build(type, parameters)
      else
        :error -> {:error, "Map provided is not a valid transformation"}
      end
    end)
  end

  def validate(transformations) do
    Enum.map(transformations, fn transformation ->
      with {:ok, type} <- Map.fetch(transformation, :type),
           {:ok, parameters} <- Map.fetch(transformation, :parameters) do
        case Transformers.OperationBuilder.validate(type, parameters) do
          {:ok, _} -> {:ok, "Transformation valid."}
          {:error, _} -> {:error, "Transformation not valid."}
        end
      else
        :error -> {:error, "Map provided is not a valid transformation"}
      end
    end)
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

  def perform(operations, initial_payload) do
    if(OperationUtils.allOperationsItemsAreFunctions(operations)) do
      executeOperations(operations, initial_payload)
    else
      {:error, "Invalid list of functions passed to performTransformations"}
    end
  end
end
