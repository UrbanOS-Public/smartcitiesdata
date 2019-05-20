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
    updated_fields =
      dataset_stats
      |> Map.get(:fields, %{})
      |> update_fields_map(dataset, row)

    dataset_stats
    |> Map.update(:record_count, 1, fn value -> value + 1 end)
    |> Map.put(:fields, updated_fields)
  end

  defp update_fields_map(existing_field_map, dataset, data) do
    dataset.technical.schema
    |> get_fields()
    |> Enum.reduce(existing_field_map, fn field, field_stats ->
      update_field_count(field_stats, field, data)
    end)
  end

  defp update_field_count(field_stats, %{name: field_name} = field, data) do
    field_path = String.split(field_name, ".")

    field_stats
    |> ensure_field_counter(field)
    |> evaluate_field_count(field, field_path, data)
  end

  defp ensure_field_counter(field_stats, %{name: field_name} = field) do
    if counter_has_not_been_initialized(field_stats, field_name) do
      initialize_field_counter(field_stats, field)
    else
      field_stats
    end
  end

  defp evaluate_field_count(field_stats, field, field_path, data) do
    if field_exists_in_row(data, field_path) do
      increment_field_count(field_stats, field)
    else
      field_stats
    end
  end

  defp field_exists_in_row(data, field_path) do
    value = get_in(data, field_path)

    cond do
      is_nil(value) -> false
      is_binary(value) -> String.trim(value) != ""
      true -> true
    end
  end

  defp counter_has_not_been_initialized(field_stats, field_name) do
    Map.get(field_stats, field_name, nil) == nil
  end

  defp initialize_field_counter(field_stats, %{name: field_name} = field) do
    Map.put(field_stats, field_name, %{required: Map.get(field, :required), count: 0})
  end

  defp increment_field_count(field_stats, %{name: field_name} = field) do
    field_map =
      field_stats
      |> Map.get(field_name, %{required: Map.get(field, :required), count: 0})
      |> Map.update(:count, 1, fn count -> count + 1 end)

    Map.put(field_stats, field_name, field_map)
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
