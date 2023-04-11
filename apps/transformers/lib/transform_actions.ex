defmodule Transformers do
  alias Transformers.OperationUtils

  def construct(transformations) do
    Enum.map(transformations, fn transformation ->
      with {:ok, type} <- Map.fetch(transformation, :type),
           {:ok, raw_parameters} <- Map.fetch(transformation, :parameters),
           parameters <- SmartCity.Helpers.to_string_keys(raw_parameters) do
        Transformers.OperationBuilder.build(type, parameters)
      else
        :error ->
          IO.inspect(transformation, label: "Error occurred constructing this transformation")
          {:error, "Map provided is not a valid transformation"}
      end
    end)
  end

  def validate(transformations) do
    Enum.map(transformations, fn transformation ->
      with {:ok, type} <- Map.fetch(transformation, :type),
           {:ok, raw_parameters} <- Map.fetch(transformation, :parameters),
           parameters <- SmartCity.Helpers.to_string_keys(raw_parameters) do
        case Transformers.OperationBuilder.validate(type, parameters) do
          {:ok, _} -> {:ok, "Transformation valid."}
          {:error, reasons} -> {:error, reasons}
        end
      else
        :error ->
          IO.inspect(transformation, label: "Error occurred validating this transformation")
          {:error, "Map provided is not a valid transformation"}
      end
    end)
  end

  def perform(operations, initial_payload) do
    if(OperationUtils.allOperationsItemsAreFunctions(operations)) do
      executeOperations(operations, initial_payload)
    else
      IO.inspect(operations, label: "Error occurred executing these ops")
      {:error, "Invalid list of functions passed to performTransformations"}
    end
  end

  defp executeOperations(operations, initial_payload) do
    flatten_payload = flatten_payload(initial_payload)

    result_payload = Enum.reduce_while(operations, {:ok, flatten_payload}, fn op, {:ok, acc_payload} ->
      case op.(acc_payload) do
        {:ok, result} ->
          {:cont, {:ok, result}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)

    case result_payload do
      {:ok, payload} -> {:ok, split_payload(payload)}
      error -> error
    end

  end

  defp flatten_payload(payload, parent_key \\ "") do
    Enum.reduce(payload, %{}, fn {key, value}, acc ->
      case value do
        value when is_map(value) ->
          child_payload = flatten_payload(value, concat_key(key, parent_key))
          Map.merge(acc, child_payload)
        value when is_list(value) ->
          IO.inspect("Nicholas - list")
          acc
        value -> Map.put(acc, concat_key(key, parent_key), value)
      end
    end)
  end

  defp concat_key(key, parent_key) do
    case parent_key do
      "" -> key
      _ -> "#{parent_key}.#{key}"
    end
  end

  defp split_payload(payload) do
    Enum.reduce(payload, %{}, fn {key, value}, acc ->
      case String.split(key, ".") do
        hierarchy when length(hierarchy) == 1 -> Map.put(acc, hd(hierarchy), value)
        hierarchy ->
          {parent_key, child_hierarchy} = List.pop_at(hierarchy, 0)
          parent_map = Map.get(acc, parent_key, %{})

          updated_parent_map = create_child_map(child_hierarchy, value)
            |> Map.merge(parent_map)

          Map.put(acc, parent_key, updated_parent_map)
      end
    end)
  end

  defp create_child_map(hierarchy, value) do
    {parent_key, child_hierarchy} = List.pop_at(hierarchy, 0)
    case hierarchy do
      hierarchy when length(hierarchy) == 1 -> Map.new([{hd(hierarchy), value}])
      _ -> Map.new([{parent_key, create_child_map(child_hierarchy, value)}])
    end
  end
end
