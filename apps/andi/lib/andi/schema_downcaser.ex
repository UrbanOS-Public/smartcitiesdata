defmodule Andi.SchemaDowncaser do
  def downcase_schema(schema) when is_list(schema) do
    Enum.map(schema, &downcase_field/1)
  end

  def downcase_schema(bad_schema), do: bad_schema

  defp downcase_field(%{"name" => name} = field) do
    Map.put(field, "name", String.downcase(name))
  end
end
