defmodule Valkyrie.Validators do
  @moduledoc false

  def schema_satisfied?(payload, schema) do
    Enum.all?(schema, &field_present?(&1, payload))
  end

  defp field_present?(%{name: name, type: "map", subSchema: sub_schema}, payload) do
    schema_satisfied?(payload[String.to_atom(name)], sub_schema)
  end

  defp field_present?(%{name: name, type: "list", itemType: "map", subSchema: sub_schema}, payload) do
    schemas_with_maps = Enum.zip(sub_schema, payload[String.to_atom(name)])

    Enum.reduce_while(schemas_with_maps, true, fn {schema, map}, true ->
      if schema_satisfied?(map, schema), do: {:cont, true}, else: {:halt, false}
    end)
  end

  defp field_present?(%{name: name}, payload) do
    payload
    |> Map.get(String.to_atom(name))
    |> case do
         nil -> false
         _ -> true
       end
  end

end
