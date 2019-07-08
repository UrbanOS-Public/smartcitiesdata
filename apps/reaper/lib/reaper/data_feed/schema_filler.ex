defmodule Reaper.DataFeed.SchemaFiller do
  @moduledoc false

  @doc """
  Given a schema, recursively replace a payload's empty maps with nils and add missing keys to maps that don't have their full set of keys.
  """
  def fill(schema, payload) do
    Enum.reduce(schema, payload, &fill_missing_fields/2)
  end

  defp fill_missing_fields(%{name: name, type: "map", subSchema: sub_schema}, payload) do
    value = get_not_nil_map_value(payload, name, %{})

    Map.put(payload, name, fill(sub_schema, value))
  end

  defp fill_missing_fields(%{name: name, type: "list", subSchema: sub_schema}, payload) do
    case Map.get(payload, name) do
      [] ->
        payload

      nil ->
        Map.put(payload, name, [])

      list ->
        list_values =
          list
          |> Enum.filter(fn item -> item != %{} && item != nil end)
          |> Enum.map(fn item -> fill(sub_schema, item) end)

        Map.put(payload, name, list_values)
    end
  end

  defp fill_missing_fields(%{name: name}, payload) do
    case Map.has_key?(payload, name) do
      true -> payload
      false -> Map.put(payload, name, nil)
    end
  end

  # Map.get/3 will return nil if the property doesn't exist. If it exists, it will return that value, even if nil.
  defp get_not_nil_map_value(map, key, default) do
    case Map.get(map, key) do
      nil -> default
      other -> other
    end
  end
end
