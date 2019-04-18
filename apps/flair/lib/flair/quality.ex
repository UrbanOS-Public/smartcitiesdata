defmodule Flair.Quality do
  @moduledoc false

  alias SmartCity.Dataset

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

  def calculate_nulls do
    # return count of null fields
  end
end
