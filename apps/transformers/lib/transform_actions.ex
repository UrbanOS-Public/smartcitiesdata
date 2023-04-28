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

    result_payload =
      Enum.reduce_while(operations, {:ok, flatten_payload}, fn op, {:ok, acc_payload} ->
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
    case payload do
      payload when is_list(payload) ->
        flatten_list(payload, parent_key)

      payload when is_map(payload) ->
        flatten_map(payload, parent_key)
    end
  end

  defp flatten_list(payload, parent_key) do
    case payload do
      payload when is_list(payload) ->
        payload
          |> Enum.with_index()
          |> Enum.reduce(%{}, fn {value, index}, enum_acc ->
            new_parent_key = "#{parent_key}[#{index}]"
            Map.merge(enum_acc, flatten_list(value, new_parent_key))
          end)
      payload ->
        %{parent_key => payload}
    end
  end

  defp flatten_map(payload, parent_key) do
    Enum.reduce(payload, %{}, fn {key, value}, acc ->
      case value do
        value when is_map(value) ->
          child_payload = flatten_payload(value, concat_key(key, parent_key))
          Map.merge(acc, child_payload)

        value when is_list(value) ->
          value
          |> Enum.with_index()
          |> Enum.reduce(acc, fn {value, index}, enum_acc ->
            parent_key = "#{concat_key(key, parent_key)}[#{index}]"

            case value do
              innerListValue when is_list(innerListValue) ->
                child_payload = flatten_payload(innerListValue, parent_key)
                Map.merge(enum_acc, child_payload)

              innerMapValue when is_map(innerMapValue) ->
                child_payload = flatten_payload(innerMapValue, parent_key)
                Map.merge(enum_acc, child_payload)

              primitiveValue ->
                Map.put(enum_acc, parent_key, primitiveValue)
            end
          end)

        value ->
          Map.put(acc, concat_key(key, parent_key), value)
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
    payload
      |> Map.keys()
      |> Enum.sort()
      |> Enum.reduce(%{}, fn key, acc ->
        value = Map.get(payload, key)

        case String.split(key, ".") do
          [head | []] ->
            if Regex.match?(~r/\[.\]/, head) do
              base_parent_key = Regex.replace(~r/\[.\]/, key, "")
              list_acc = Map.get(acc, base_parent_key, [])

              updated_list = Regex.scan(~r/\[.\]/, head)
                |> split_list(value, list_acc)

              Map.put(acc, base_parent_key, updated_list)
            else
              Map.put(acc, key, value)
            end
          hierarchy ->
            {parent_key, child_hierarchy} = List.pop_at(hierarchy, 0)

            if Regex.match?(~r/\[.\]/, parent_key) do
              base_parent_key = Regex.replace(~r/\[.\]/, key, "")
              list_acc = Map.get(acc, base_parent_key, [])

              updated_list = Regex.scan(~r/\[.\]/, parent_key)
                |> split_list(value, list_acc)

              Map.put(acc, base_parent_key, updated_list)
            else
              map_child(parent_key, child_hierarchy, value, acc)
            end
        end
      end)
  end

  defp split_list(index_list, value, list_acc) do
    {first_index_str, popped_list} = List.pop_at(index_list, 0)
    first_index = Regex.replace(~r/\[|\]/, first_index_str |> hd(), "")
      |> String.to_integer()

    {list_acc_at_index, rest_of_list} = List.pop_at(list_acc, first_index, [])
    new_value = if Enum.any?(popped_list), do: split_list(popped_list, value, list_acc_at_index), else: value

    List.insert_at(rest_of_list, first_index, new_value)
  end

  defp map_child(parent_key, child_hierarchy, value, acc) do
    parent_map = Map.get(acc, parent_key, %{})

    updated_parent_map =
      create_child_map(child_hierarchy, value)
      |> Map.merge(parent_map)

    Map.put(acc, parent_key, updated_parent_map)
  end

  defp create_child_map(hierarchy, value) do
    {parent_key, child_hierarchy} = List.pop_at(hierarchy, 0)

    case hierarchy do
      hierarchy when length(hierarchy) == 1 -> Map.new([{hd(hierarchy), value}])
      _ -> Map.new([{parent_key, create_child_map(child_hierarchy, value)}])
    end
  end
end
