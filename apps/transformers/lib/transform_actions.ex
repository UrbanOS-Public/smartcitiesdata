defmodule Transformers do
  require Logger

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
    |> NaturalSort.sort()
    |> Enum.map(fn key ->
      {key, split_key_into_accessors(key)}
    end)
    |> Enum.reduce(%{}, fn {key, accessors}, acc ->
      value = Map.get(payload, key)
      put_value_with_accessor_keys(value, accessors, acc)
    end)
  end

  def put_value_with_accessor_keys(value, [head | []] = accessor_keys, acc)
      when is_integer(head) do
    acc ++ [value]
  end

  def put_value_with_accessor_keys(value, [head | []] = accessor_keys, acc)
      when is_binary(head) do
    Map.merge(acc, %{head => value})
  end

  def put_value_with_accessor_keys(value, [head | []] = accessor_keys, acc) do
    raise("#{head} is not an integer or binary for value element placement")
  end

  def put_value_with_accessor_keys(value, [head | tail] = accessor_keys, acc)
      when is_binary(head) do
    case tail do
      [head_of_tail | _] when is_integer(head_of_tail) ->
        current_value = Map.get(acc, head, [])
        Map.put(acc, head, put_value_with_accessor_keys(value, tail, current_value))

      [head_of_tail | _] when is_binary(head_of_tail) ->
        current_value = Map.get(acc, head, %{})
        Map.put(acc, head, put_value_with_accessor_keys(value, tail, current_value))
    end
  end

  def put_value_with_accessor_keys(value, [head | tail] = accessor_keys, acc)
      when is_integer(head) do
    new_acc =
      case tail do
        [head_of_tail | _] when is_integer(head_of_tail) ->
          current_value = Enum.at(acc, head, [])

          if length(acc) == head do
            acc ++ [put_value_with_accessor_keys(value, tail, current_value)]
          else
            List.replace_at(acc, head, put_value_with_accessor_keys(value, tail, current_value))
          end

        [head_of_tail | _] when is_binary(head_of_tail) ->
          current_value = Enum.at(acc, head, %{})

          if length(acc) == head do
            acc ++ [put_value_with_accessor_keys(value, tail, current_value)]
          else
            List.replace_at(acc, head, put_value_with_accessor_keys(value, tail, current_value))
          end
      end
  end

  def split_key_into_accessors(key, acc \\ [])

  def split_key_into_accessors(key, acc) when key == "" do
    Enum.reverse(acc)
  end

  def split_key_into_accessors(key, acc) do
    child_list_accessor = Regex.run(~r/^(\[\d+\])/, key, capture: :all_but_first)
    named_list_accessor = Regex.run(~r/^([\w_-]+\[\d+\])/, key, capture: :all_but_first)
    map_list_accessor = Regex.run(~r/^([\w_-]+\.)/, key, capture: :all_but_first)
    child_map_accessor = Regex.run(~r/^(\.)/, key, capture: :all_but_first)
    map_accessor = Regex.run(~r/^([\w_-]+)/, key, capture: :all_but_first)

    shortest_accessor =
      [
        child_list_accessor,
        named_list_accessor,
        map_list_accessor,
        child_map_accessor,
        map_accessor
      ]
      |> Enum.reject(&is_nil/1)

    if length(shortest_accessor) == 0 do
      Logger.error("No accessor was found for key: #{key}")
    end

    shortest_accessor =
      shortest_accessor
      |> Enum.map(fn [accessor] -> accessor end)
      |> Enum.min_by(fn accessor -> String.length(accessor) end)

    length_of_accessor = String.length(shortest_accessor)
    remaining_key = String.slice(key, length_of_accessor..-1)

    case [shortest_accessor] do
      ^child_list_accessor ->
        trimmed_key =
          shortest_accessor
          |> String.replace("[", "")
          |> String.replace("]", "")

        updated_accessor_list = [String.to_integer(trimmed_key) | acc]
        split_key_into_accessors(remaining_key, updated_accessor_list)

      ^named_list_accessor ->
        [map_accessor, list_accessor] =
          Regex.run(~r/^(\w+)\[(\d+)\]/, shortest_accessor, capture: :all_but_first)

        updated_accessor_list = [String.to_integer(list_accessor) | [map_accessor | acc]]

        split_key_into_accessors(remaining_key, updated_accessor_list)

      ^map_list_accessor ->
        trim_dot = String.slice(shortest_accessor, 0..-2)
        updated_accessor_list = [trim_dot | acc]
        split_key_into_accessors(remaining_key, updated_accessor_list)

      ^child_map_accessor ->
        split_key_into_accessors(remaining_key, acc)

      ^map_accessor ->
        updated_accessor_list = [shortest_accessor | acc]
        split_key_into_accessors(remaining_key, updated_accessor_list)
    end
  end
end
