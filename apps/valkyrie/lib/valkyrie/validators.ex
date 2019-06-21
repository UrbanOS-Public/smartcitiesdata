defmodule Valkyrie.Validators do
  @moduledoc """
  Given a payload, valkyrie retrieves the schema and checks that every field in the schema has a non-null value in the payload.
  """

  require Logger
  alias SmartCity.Data

  @doc """
   Check that the dataset's fields exist in the payload.
  """
  @spec validate(SmartCity.Data.t()) :: {:ok, SmartCity.Data.t()} | {:error, String.t()}
  def validate(%Data{dataset_id: id, payload: payload} = message) do
    %Valkyrie.Dataset{schema: schema} = Valkyrie.Dataset.get(id)

    invalid_fields = get_invalid_fields(payload, schema)

    if Enum.empty?(invalid_fields) do
      {:ok, message}
    else
      fields = Enum.join(invalid_fields, ", ")
      {:error, "The following fields were invalid: #{fields}"}
    end
  end

  @doc """
  Returns a list of fields that are in schema but do not exist in the payload.
  # Examples
        iex> schema = [
        ...> %{name: "name", type: "string"},
        ...> %{name: "age", type: "integer"},
        ...> %{name: "hobbies", type: "list", itemType: "string"}
        ...> ]
        ...> payload = %{name: "Peggy", age: 37}
        ...> Valkyrie.Validators.get_invalid_fields(payload, schema)
        ["hobbies"]
  """
  @spec get_invalid_fields(map(), map()) :: list(String.t())
  def get_invalid_fields(nil, schema), do: []
  def get_invalid_fields(payload, schema) when payload == %{}, do: []

  def get_invalid_fields(payload, schema) do
    schema
    |> Enum.map(&get_invalid_field_or_header(&1, payload))
    |> List.flatten()
  end

  defp get_invalid_field_or_header(%{name: name} = field, payload) do
    if not_header?(field, payload) do
      get_invalid_sub_fields(field, payload)
    else
      [name]
    end
  end

  defp get_invalid_sub_fields(%{name: name, type: "map", subSchema: sub_schema}, payload) do
    get_invalid_fields(payload[String.to_atom(name)], sub_schema)
  end

  defp get_invalid_sub_fields(
         %{name: name, type: "list", itemType: "map", subSchema: sub_schema},
         payload
       ) do
    schemas_with_maps = Enum.zip(sub_schema, payload[String.to_atom(name)])

    Enum.map(schemas_with_maps, fn {schema, map} ->
      get_invalid_fields(map, schema)
    end)
  end

  defp get_invalid_sub_fields(%{name: name}, payload) do
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

    if field_name in payload_keys do
      []
    else
      [Atom.to_string(field_name)]
    end
  end

  defp not_header?(%{name: name}, payload) do
    atom_name = String.to_atom(name)

    case Map.get(payload, atom_name) do
      value when not is_binary(value) ->
        true

      value ->
        String.downcase(value) != String.downcase(name)
    end
  end
end
