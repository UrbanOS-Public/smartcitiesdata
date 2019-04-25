defmodule Valkyrie.Validators do
  @moduledoc false

  def schema_satisfied?(payload, schema) do
    Enum.all?(schema, fn field ->
      field_present?(field, payload) && not_header?(field, payload)
    end)
  end

  defp field_present?(%{name: name, type: "map", subSchema: sub_schema}, payload) do
    schema_satisfied?(payload[String.to_atom(name)], sub_schema)
  end

  defp field_present?(
         %{name: name, type: "list", itemType: "map", subSchema: sub_schema},
         payload
       ) do
    schemas_with_maps = Enum.zip(sub_schema, payload[String.to_atom(name)])

    Enum.reduce_while(schemas_with_maps, true, fn {schema, map}, true ->
      if schema_satisfied?(map, schema), do: {:cont, true}, else: {:halt, false}
    end)
  end

  defp field_present?(%{name: name}, payload) do
    name =
      name
      |> String.downcase()
      |> String.to_atom()

    Map.has_key?(payload, name)
  end

  defp not_header?(%{name: name}, payload) do
    atom_name = String.to_atom(name)
    Map.get(payload, atom_name) != name
  end
end
