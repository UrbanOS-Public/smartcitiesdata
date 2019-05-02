defmodule Valkyrie.Validators do
  @moduledoc false

  def get_invalid_fields(payload, schema) do
    Enum.map(schema, fn %{name: name} = field ->
      case field_present?(field, payload) && not_header?(field, payload) do
        true -> nil
        _ -> name
      end
    end)
    |> Enum.reject(fn field -> field == nil end)
  end

  defp field_present?(%{name: name, type: "map", subSchema: sub_schema}, payload) do
    valid = get_invalid_fields(payload[String.to_atom(name)], sub_schema)
    valid
  end

  defp field_present?(
         %{name: name, type: "list", itemType: "map", subSchema: sub_schema},
         payload
       ) do
    schemas_with_maps = Enum.zip(sub_schema, payload[String.to_atom(name)])

    Enum.reduce_while(schemas_with_maps, true, fn {schema, map}, true ->
      if length(get_invalid_fields(map, schema)) == 0, do: {:cont, true}, else: {:halt, false}
    end)
  end

  defp field_present?(%{name: name}, payload) do
    field_name =
      name
      |> String.downcase()
      |> String.to_atom()

    payload_keys =
      payload
      |> Map.keys()
      |> Enum.map(fn key ->
        key
        |> Atom.to_string()
        |> String.downcase()
        |> String.to_atom()
      end)

    field_name in payload_keys
  end

  defp not_header?(%{name: name}, payload) do
    atom_name = String.to_atom(name)

    not_header =
      case Map.get(payload, atom_name) do
        value when not is_binary(value) ->
          true

        value ->
          String.downcase(value) != String.downcase(name)
      end

    not_header
  end
end
