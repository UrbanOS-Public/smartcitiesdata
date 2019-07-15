defmodule Valkyrie do
  @moduledoc """
  Main Business logic for Valkyrie, including validated a data messages matches the dataset schema
  """

  alias SmartCity.Data
  alias Valkyrie.Dataset

  @type reason :: %{String.t() => term()}

  @spec validate_data(%Dataset{}, %Data{}) :: :ok | {:error, reason()}
  def validate_data(%Dataset{schema: schema} = dataset, %Data{payload: payload} = data) do
    validation_failures = validate_schema(schema, payload)

    case Enum.empty?(validation_failures) do
      true -> :ok
      false -> {:error, validation_failures}
    end
  end

  defp validate_schema(schema, payload) do
    schema
    |> Enum.reduce(%{}, fn %{name: name} = field, errors ->
      case validate(field, payload[name]) do
        :ok -> errors
        reason -> Map.put(errors, name, reason)
      end
    end)
  end

  defp validate(_type, nil), do: :ok

  defp validate(%{type: "string"}, value) do
    case String.valid?(value) do
      true -> :ok
      false -> :invalid_string
    end
  end

  defp validate(%{type: type}, value) when type in ["integer", "long"] and is_integer(value), do: :ok

  defp validate(%{type: type}, value) when type in ["integer", "long"] do
    case Integer.parse(value) do
      {_value, ""} -> :ok
      _ -> :"invalid_#{type}"
    end
  end

  defp validate(%{type: "boolean"}, value) when is_boolean(value), do: :ok

  defp validate(%{type: "boolean"}, value) do
    case value do
      "true" -> :ok
      "false" -> :ok
      _ -> :invalid_boolean
    end
  end

  defp validate(%{type: type}, value) when type in ["float", "double"] and (is_integer(value) or is_float(value)),
    do: :ok

  defp validate(%{type: type}, value) when type in ["float", "double"] do
    case Float.parse(value) do
      {_value, ""} -> :ok
      _ -> :"invalid_#{type}"
    end
  end

  defp validate(%{type: type, format: format}, value) when type in ["date", "timestamp"] do
    case Timex.parse(value, format) do
      {:ok, _value} -> :ok
      {:error, reason} -> {:"invalid_#{type}", reason}
    end
  end

  defp validate(%{type: "map", subSchema: sub_schema}, value) do
    case validate_schema(sub_schema, value) do
      map when map == %{} -> :ok
      errors -> errors
    end
  end
end
