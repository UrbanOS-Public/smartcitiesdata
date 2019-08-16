defmodule Valkyrie do
  @moduledoc """
  Main Business logic for Valkyrie
  Validating and transforming the payload to conform to the provided dataset schema
  """

  alias SmartCity.Dataset

  @type reason :: %{String.t() => term()}

  @spec standardize_data(%Dataset{}, map()) :: {:ok, map()} | {:error, reason()}
  def standardize_data(%Dataset{technical: %{schema: schema}}, payload) do
    %{data: data, errors: errors} = standardize_schema(schema, payload)

    case Enum.empty?(errors) do
      true -> {:ok, data}
      false -> {:error, errors}
    end
  end

  defp standardize_schema(schema, payload) do
    schema
    |> Enum.reduce(%{data: %{}, errors: %{}}, fn %{name: name} = field, acc ->
      case standardize(field, payload[name]) do
        {:ok, value} -> %{acc | data: Map.put(acc.data, name, value)}
        {:error, reason} -> %{acc | errors: Map.put(acc.errors, name, reason)}
      end
    end)
  end

  defp standardize(_field, nil), do: {:ok, nil}

  defp standardize(%{type: "string"}, value) do
    {:ok, value |> to_string() |> String.trim()}
  rescue
    Protocol.UndefinedError -> {:error, :invalid_string}
  end

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

  defp standardize(%{type: "list"}, value) when not is_list(value), do: {:error, :invalid_list}

  defp standardize(%{type: "list"} = field, value) do
    case standardize_list(field, value) do
      {:ok, reversed_list} -> {:ok, Enum.reverse(reversed_list)}
      {:error, reason} -> {:error, {:invalid_list, reason}}
    end
  end

  defp standardize(_, _) do
    {:error, :invalid_type}
  end

  defp standardize_list(%{itemType: item_type} = field, value) do
    value
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {item, index}, {:ok, acc} ->
      case standardize(%{type: item_type, subSchema: field[:subSchema]}, item) do
        {:ok, new_value} -> {:cont, {:ok, [new_value | acc]}}
        {:error, reason} -> {:halt, {:error, "#{inspect(reason)} at index #{index}"}}
      end
    end)
  end
end
