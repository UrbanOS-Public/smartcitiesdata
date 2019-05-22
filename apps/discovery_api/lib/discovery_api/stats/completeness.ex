defmodule DiscoveryApi.Stats.Completeness do
  @moduledoc """
  Calculate data completeness. This is done by reducing multiple data messages to an accumulater of non-nil columns recursively through the data hierarchy.
  """

  @doc """
  A reducing function which accumulates completeness statistics for a row in a dataset

  ## Parameters
  - dataset: The [SmartCity Dataset](https://github.com/smartcitiesdata/smart_city_data) for which stats are being accumulated
  - row: A single row of data as a map, e.g. %{"id" => 1, "name" => "John Doe"}
  - dataset_stats: The statistics accumulator.  This stores the running totals of the statistics and is intended to be the accumulator in a reduce function.
  """

  def calculate_stats_for_row(dataset, row, dataset_stats) do
    dataset_stats
    |> Map.update(:record_count, 1, fn value -> value + 1 end)
    |> Map.put(:fields, update_fields_map(dataset_stats, dataset, row))
  end

  defp update_fields_map(stats_map, dataset, data) do
    existing_field_map = Map.get(stats_map, :fields, %{})

    dataset.technical.schema
    |> get_fields()
    |> Enum.reduce(existing_field_map, fn field, field_stats ->
      update_field_count(field_stats, field, data)
    end)
  end

  defp update_field_count(field_stats, %{name: field_name} = field, data) do
    field_path = String.split(field_name, ".")

    field_stats
    |> increment_field_count(field, field_path, data)
  end

  defp field_count_in_row(data, field_path) do
    value = get_in(data, field_path)

    cond do
      is_nil(value) ->
        0

      is_binary(value) && String.trim(value) == "" ->
        0

      true ->
        1
    end
  end

  defp increment_field_count(field_stats, %{name: field_name, required: required} = field, field_path, data) do
    count_in_row = field_count_in_row(data, field_path)

    Map.update(
      field_stats,
      field_name,
      %{required: required, count: count_in_row},
      fn %{required: required, count: count} ->
        %{required: required, count: count + count_in_row}
      end
    )
  end

  defp get_fields(schema) do
    schema
    |> Enum.map(fn field -> get_sub_fields(field, "") end)
    |> List.flatten()
    |> remove_dot()
  end

  defp remove_dot([]), do: []

  defp remove_dot(list) do
    Enum.map(list, fn map ->
      Map.update!(map, :name, fn name -> String.slice(name, 1..(String.length(name) - 1)) end)
    end)
  end

  defp get_sub_fields(field, parent_name) do
    if Map.get(field, :subSchema, nil) == nil do
      name = parent_name <> "." <> Map.get(field, :name)

      [%{name: name, required: Map.get(field, :required, false)}]
    else
      name = parent_name <> "." <> Map.get(field, :name)

      sub_field =
        field
        |> Map.get(:subSchema)
        |> Enum.map(fn sub_field -> get_sub_fields(sub_field, name) end)

      sub_field ++ [[%{name: name, required: Map.get(field, :required, false)}]]
    end
  end
end
