defmodule Valkyrie do
  @moduledoc """
  Main Business logic for Valkyrie
  Validating and transforming the payload to conform to the provided dataset schema
  """
  require Logger
  alias SmartCity.Dataset

  def instance_name(), do: :valkyrie_brook

  @type reason :: %{String.t() => term()}

  @spec standardize_data(Dataset.t(), map()) :: {:ok, map()} | {:error, reason()}
  def standardize_data(%Dataset{technical: %{schema: schema}}, payload) do
    %{data: data, errors: errors} = standardize_schema(schema, payload)

    case Enum.empty?(errors) do
      true -> {:ok, data}
      false -> {:error, errors}
    end
  end

  defp standardize_schema(schema, payload) do
    schema
    |> Enum.reduce(%{data: %{}, errors: %{}}, fn
      %{ingestion_field_selector: selector, name: name} = field, acc ->
        try do
          case standardize(field, payload[selector]) do
            {:ok, value} ->
              %{acc | data: Map.put(acc.data, name, value)}

            {:error, reason} ->
              %{acc | errors: Map.put(acc.errors, name, reason)}
          end
        rescue
          exception -> %{acc | errors: Map.put(acc.errors, name, %{unhandled_standardization_exception: exception})}
        end

      %{name: name} = field, acc ->
        Logger.error(
          "Found a dataset schema: #{name} field without :ingestion_field_selector. This should not happen. Defaulting to name of field."
        )

        defaulted_field = Map.put(field, :ingestion_field_selector, name)

        try do
          case standardize(defaulted_field, payload[name]) do
            {:ok, value} -> %{acc | data: Map.put(acc.data, name, value)}
            {:error, reason} -> %{acc | errors: Map.put(acc.errors, name, reason)}
          end
        rescue
          exception -> %{acc | errors: Map.put(acc.errors, name, %{unhandled_standardization_exception: exception})}
        end
    end)
  end

  defp standardize(_field, nil), do: {:ok, nil}

  defp standardize(%{type: "string"}, value) do
    {:ok, value |> to_string() |> String.trim()}
  rescue
    Protocol.UndefinedError -> {:error, :invalid_string}
  end

  defp standardize(_, ""), do: {:ok, nil}

  defp standardize(%{type: type}, value) when type in ["integer", "long"] and is_integer(value), do: {:ok, value}

  defp standardize(%{type: type}, value) when type in ["integer", "long"] do
    case Integer.parse(value) do
      {parsed_value, ""} -> {:ok, parsed_value}
      _ -> {:error, :"invalid_#{type}"}
    end
  end

  defp standardize(%{type: "boolean"}, value) when is_boolean(value), do: {:ok, value}

  defp standardize(%{type: "boolean"}, value) do
    case value do
      "true" -> {:ok, true}
      "false" -> {:ok, false}
      _ -> {:error, :invalid_boolean}
    end
  end

  defp standardize(%{type: type}, value) when type in ["float", "double"] and (is_integer(value) or is_float(value)),
    do: {:ok, value / 1}

  defp standardize(%{type: type}, value) when type in ["float", "double"] do
    case Float.parse(value) do
      {parsed_value, ""} -> {:ok, parsed_value}
      _ -> {:error, :"invalid_#{type}"}
    end
  end

  defp standardize(%{type: type, format: format}, value) when type in ["date", "timestamp"] do
    case Timex.parse(value, format) do
      {:ok, parsed_value} -> {:ok, parsed_value}
      {:error, reason} -> {:error, {:"invalid_#{type}", reason}}
    end
  end

  defp standardize(%{type: "json"}, value) do
    case Jason.encode(value) do
      {:ok, result} -> {:ok, result}
      _ -> {:error, :invalid_json}
    end
  end

  defp standardize(%{type: "map"}, value) when not is_map(value), do: {:error, :invalid_map}

  defp standardize(%{type: "map", subSchema: sub_schema}, value) do
    %{data: data, errors: errors} = standardize_schema(sub_schema, value)

    case Enum.empty?(errors) do
      true -> {:ok, data}
      false -> {:error, errors}
    end
  end

  defp standardize(%{type: "list"}, value) when not is_list(value) do
    {:error, :invalid_list}
  end

  defp standardize(%{type: "list", itemType: "map"} = field, value) do
    result =
      Enum.reduce_while(value, {:ok, []}, fn
        inner_map, {:ok, acc} when is_map(inner_map) ->
          wrapped_schema = %{name: "doesntMatter", type: "map", subSchema: field.subSchema}

          case standardize(wrapped_schema, inner_map) do
            {:ok, standardized_list} ->
              {:cont, {:ok, [standardized_list | acc]}}

            {:error, reason} ->
              {:halt, {:error, reason}}
          end

        not_a_map, {:ok, acc} ->
          {:halt, {:error, "#{field.name} is a list with subtype map, but has children that are not maps"}}
      end)

    case result do
      {:error, reason} ->
        {:error, reason}

      {:ok, reversed_list} ->
        {:ok, Enum.reverse(reversed_list)}
    end
  end

  defp standardize(%{type: "list", itemType: "list", subSchema: [head | tail]} = field, value) when tail != [] do
    {:error,
     {:invalid_list,
      "#{field.name} is a list of lists, but has multiple subschema. Lists must contain only a single subschema"}}
  end

  defp standardize(%{type: "list", itemType: "list", subSchema: [actual_subschema | tail]} = field, value) do
    result =
      Enum.reduce_while(value, {:ok, []}, fn
        inner_list, {:ok, acc} when is_list(inner_list) ->
          case standardize(actual_subschema, inner_list) do
            {:ok, standardized_list} ->
              {:cont, {:ok, [standardized_list | acc]}}

            {:error, reason} ->
              {:halt, {:error, reason}}
          end

        not_a_list, {:ok, acc} ->
          {:halt, {:error, "#{field.name} is a list, but has children that are not lists"}}
      end)

    case result do
      {:error, reason} -> {:error, reason}
      {:ok, standardized_list} -> {:ok, Enum.reverse(standardized_list)}
    end
  end

  defp standardize(%{type: "list", itemType: _} = field, value) do
    case standardize_list(field, value) do
      {:ok, reversed_list} -> {:ok, Enum.reverse(reversed_list)}
      {:error, reason} -> {:error, {:invalid_list, reason}}
    end
  end

  defp standardize(%{type: "list"} = field, value),
    do: {:error, {:invalid_list, "#{field.name} has no itemType. Lists must have itemTypes defined in the schema"}}

  defp standardize(ss, v) do
    {:error, :invalid_type}
  end

  defp standardize_list(%{type: "list", itemType: "list"} = field, value) do
    value
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {item, index}, {:ok, acc} ->
      case item do
        item when is_list(item) ->
          case standardize(field.subSchema, item) do
            {:ok, new_value} ->
              {:cont, {:ok, [Enum.reverse(new_value) | acc]}}

            {:error, reason} ->
              {:halt, {:error, "#{inspect(reason)} at index #{index}"}}
          end

        _ ->
          {:halt, {:error, "#{field.name} is a list of lists, but contains a non-list child at #{index}: #{item}"}}
      end
    end)
  end

  defp standardize_list(%{type: "list", itemType: "map"} = field, value) do
    value
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {item, index}, {:ok, acc} ->
      case item do
        item when is_map(item) ->
          case standardize(field.subSchema, item) do
            {:ok, new_value} ->
              {:cont, {:ok, [Enum.reverse(new_value) | acc]}}

            {:error, reason} ->
              {:halt, {:error, "#{inspect(reason)} at index #{index}"}}
          end

        _ ->
          {:halt, {:error, "#{field.name} is a list of maps, but contains a non-list child at #{index}: #{item}"}}
      end
    end)
  end

  defp standardize_list(%{type: "list", itemType: item_type} = field, value) do
    value
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {item, index}, {:ok, acc} ->
      case item do
        item ->
          case standardize(%{type: item_type, subSchema: field[:subSchema]}, item) do
            {:ok, new_value} -> {:cont, {:ok, [new_value | acc]}}
            {:error, reason} -> {:halt, {:error, "#{inspect(reason)} at index #{index}"}}
          end
      end
    end)
  end
end
