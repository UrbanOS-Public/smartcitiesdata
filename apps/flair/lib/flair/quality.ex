defmodule Flair.Quality do
  @moduledoc false

  alias SmartCity.Dataset
  alias SmartCity.Data

  def get_required_fields(dataset_id) do
    Dataset.get!(dataset_id).technical.schema
    |> Enum.map(fn field -> get_sub_required_fields(field) end)
    |> List.flatten()
  end

  defp get_sub_required_fields(required_field) do
    cond do
      Map.get(required_field, :required, false) == false ->
        []

      Map.get(required_field, :subSchema, nil) == nil ->
        [Map.get(required_field, :name)]

      true ->
        sub_field =
          required_field
          |> Map.get(:subSchema)
          |> Enum.map(fn sub_field -> get_sub_required_fields(sub_field) end)

        sub_field ++ [Map.get(required_field, :name)]
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
    if Map.get(data, field_name, nil) != nil do
      Map.update(acc, field_name, 1, fn existing_value -> existing_value + 1 end)
    else
      Map.update(acc, field_name, 0, fn existing_value -> existing_value end)
    end
  end
end
