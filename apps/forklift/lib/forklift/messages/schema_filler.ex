defmodule Forklift.Messages.SchemaFiller do
  @moduledoc false

  @doc """
  Given a schema, replace a payload's empty maps with nils and add missing keys to maps that don't have their full set of keys.
  """
  def fill(schema, payload) do
    Enum.reduce(schema, payload, &fill_missing_fields/2)
  end

  defp fill_missing_fields(%{name: name, type: "map", subSchema: sub_schema}, payload) do
    key = String.to_atom(name)
    value = Map.get(payload, key)

    cond do
      value == nil -> payload
      value == %{} -> Map.put(payload, key, nil)
      true -> Map.put(payload, key, fill(sub_schema, value))
    end
  end

  defp fill_missing_fields(%{name: name, type: "list", subSchema: sub_schema}, payload) do
    key = String.to_atom(name)
    list = Map.get(payload, key)

    case list do
      [] ->
        payload

      nil ->
        Map.put(payload, key, [])

      _ ->
        list_values =
          list
          |> Enum.filter(fn item -> item != %{} && item != nil end)
          |> Enum.map(fn item -> fill(sub_schema, item) end)

        Map.put(payload, key, list_values)
    end
  end

  defp fill_missing_fields(%{name: name}, payload) do
    key = String.to_atom(name)

    case Map.has_key?(payload, key) do
      true -> payload
      false -> Map.put(payload, key, nil)
    end
  end
end
