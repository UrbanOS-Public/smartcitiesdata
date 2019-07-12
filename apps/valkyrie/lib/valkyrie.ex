defmodule Valkyrie do
  @moduledoc """
  Main Business logic for Valkyrie, including validated a data messages matches the dataset schema
  """

  alias SmartCity.Data
  alias Valkyrie.Dataset

  @type reason :: %{String.t() => :atom}

  @spec validate_data(%Dataset{}, %Data{}) :: :ok | {:error, reason()}
  def validate_data(%Dataset{schema: schema} = dataset, %Data{payload: payload} = data) do
    IO.inspect(data)

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

  defp validate(%{type: "integer"}, value) when is_integer(value), do: :ok

  defp validate(%{type: "integer"}, value) do
    case Integer.parse(value) do
      {_value, ""} -> :ok
      _ -> :invalid_integer
    end
  end
end
