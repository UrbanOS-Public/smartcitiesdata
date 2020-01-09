defmodule AndiWeb.DatasetValidator do
  @moduledoc "Used to validate datasets"

  alias AndiWeb.DatasetSchemaValidator

  def validate(dataset) do
    stringified = stringify_keys(dataset)

    result = DatasetSchemaValidator.validate(stringified)

    case result do
      [] -> :valid
      errors -> {:invalid, errors}
    end
  end

  # Handles preconverting datasets from structs to maps for comparison purposes
  defp stringify_keys(%{__struct__: _} = struct), do: struct |> Map.from_struct() |> stringify_keys()

  defp stringify_keys(%{} = map) do
    map
    |> Enum.map(fn {key, value} -> {key_to_string(key), stringify_keys(value)} end)
    |> Enum.into(%{})
  end

  defp stringify_keys([head | rest]) do
    [stringify_keys(head) | stringify_keys(rest)]
  end

  defp stringify_keys(not_a_map) do
    not_a_map
  end

  defp key_to_string(key) when is_atom(key), do: Atom.to_string(key)

  defp key_to_string(key), do: key
end
