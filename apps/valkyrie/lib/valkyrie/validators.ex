defmodule Valkyrie.Validators do
  @moduledoc false

  def schema_satisfied?(message, schema) do
    Enum.all?(schema, &field_present?(&1, message.payload))
  end

  defp field_present?(%{name: name, type: "map", subSchema: sub_schema}, payload) do
    schema_satisfied?(payload[name], sub_schema)
  end

  defp field_present?(%{name: name, type: "list", itemType: "map", subSchema: sub_schema}, payload) do
    schemas_with_maps = Enum.zip(sub_schema, payload[name])

    Enum.reduce_while(schemas_with_maps, true, fn {schema, map}, true ->
      if field_present?(schema, map), do: {:cont, true}, else: {:halt, false}
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
