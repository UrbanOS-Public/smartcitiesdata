defmodule Reaper.DataExtract.SchemaFiller do
  @moduledoc false

  @doc """
  Given a schema, recursively replace a payload's empty maps with nils and add missing keys to maps that don't have their full set of keys. If a schema field has a default value, apply that to the field if missing or null.
  """
  def fill(schema, payload, child_of_list \\ false) do
    Enum.reduce(schema, payload, fn
      schema_element, acc_payload -> fill_missing_fields(schema_element, acc_payload, child_of_list)
    end)
  end

  defp fill_missing_fields(%{name: name, type: "map", subSchema: sub_schema}, payload, child_of_list) do
    if child_of_list do
      Enum.map(payload, fn element ->
        value = get_not_nil_map_value(element, name, %{})
        Map.put(element, name, fill(sub_schema, value))
      end)
    else
      value = get_not_nil_map_value(payload, name, %{})
      Map.put(payload, name, fill(sub_schema, value))
    end
  end

  defp fill_missing_fields(
         %{name: name, type: "list", itemType: "list", subSchema: sub_schema} = ss,
         payload,
         child_of_list
       ) do
    if child_of_list do
      Enum.map(payload, fn
        [] -> []
        nil -> nil
        list -> fill(sub_schema, list, true)
      end)
      |> Enum.reject(fn item -> item == nil end)
    else
      case Map.get(payload, name) do
        [] ->
          payload

        nil ->
          Map.put(payload, name, [])

        list ->
          list_values =
            list
            |> Enum.reject(fn item -> item == nil end)
            |> Enum.map(fn item -> fill(sub_schema, item, true) end)

          Map.put(payload, name, list_values)
      end
    end
  end

  defp fill_missing_fields(
         %{name: name, type: "list", itemType: "map", subSchema: sub_schema} = ss,
         payload,
         child_of_list
       ) do
    if child_of_list do
      Enum.map(payload, fn
        map when map == %{} ->
          nil

        nil ->
          nil

        map ->
          fill(sub_schema, map)
      end)
      |> Enum.reject(fn item -> item == nil end)
    else
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
  end

  defp fill_missing_fields(%{name: name, type: "list"} = ss, payload, child_of_list) do
    if child_of_list do
      payload
    else
      case Map.has_key?(payload, name) do
        true -> payload
        false -> Map.put(payload, name, [])
      end
    end
  end

  defp fill_missing_fields(%{name: name, default: default}, payload, child_of_list) do
    if child_of_list do
      default
    else
      case Map.get(payload, name) do
        nil -> Map.put(payload, name, default)
        _ -> payload
      end
    end
  end

  defp fill_missing_fields(%{name: name} = ss, payload, child_of_list) do
    if child_of_list do
      payload
    else
      case Map.has_key?(payload, name) do
        true -> payload
        false -> Map.put(payload, name, nil)
      end
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
