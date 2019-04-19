defmodule Flair.Quality do
  @moduledoc false

  alias SmartCity.Dataset
  alias SmartCity.Data

  def get_required_fields(dataset_id) do
    Dataset.get!(dataset_id).technical.schema
    |> Enum.map(fn field -> get_sub_required_fields(field, "") end)
    |> List.flatten()
    |> remove_dot()
  end

  defp remove_dot([]), do: []

  defp remove_dot(list) do
    Enum.map(list, fn value -> String.slice(value, 1..(String.length(value) - 1)) end)
  end

  defp get_sub_required_fields(required_field, parent_name) do
    cond do
      Map.get(required_field, :required, false) == false ->
        []

      Map.get(required_field, :subSchema, nil) == nil ->
        [parent_name <> "." <> Map.get(required_field, :name)]

      true ->
        name = parent_name <> "." <> Map.get(required_field, :name)

        sub_field =
          required_field
          |> Map.get(:subSchema)
          |> Enum.map(fn sub_field -> get_sub_required_fields(sub_field, name) end)

        sub_field ++ [name]
    end
  end

  def reducer(%Data{dataset_id: id, payload: data}, acc) do
    existing_map = Map.get(acc, id, %{})

    updated_map =
      id
      |> get_required_fields()
      |> Enum.reduce(existing_map, fn field_name, acc ->
        update_field_count(acc, field_name, data)
      end)
      |> Map.update(:record_count, 1, fn value -> value + 1 end)

    Map.put(acc, id, updated_map)
  end

  defp update_field_count(acc, field_name, data) do
    field_path = String.split(field_name, ".")

    if get_in(data, field_path) != nil do
      Map.update(acc, field_name, 1, fn existing_value -> existing_value + 1 end)
    else
      Map.update(acc, field_name, 0, fn existing_value -> existing_value end)
    end
  end
end
