defmodule DiscoveryApi.Stats.CompletenessTotals do
  @moduledoc """
  Provides an interface for calculating dataset completeness total with a dataset field map as input which can be calculated with DiscoveryApi.Stats.Completeness
  """
  def calculate_dataset_total(%{fields: fields, record_count: record_count}) do
    total_required_cells = get_total_cells(fields, record_count, &is_required?/1)
    total_complete_required_cells = get_total_complete_cells(fields, &is_required?/1)
    total_optional_cells = get_total_cells(fields, record_count, &is_optional?/1)
    total_complete_optional_cells = get_total_complete_cells(fields, &is_optional?/1)

    if total_required_cells > 0 do
      total_complete_required_cells / total_required_cells
    else
      total_complete_optional_cells / total_optional_cells
    end
  end

  def calculate_dataset_total(_), do: nil

  defp get_total_cells(fields, total_rows, filter) do
    Enum.count(fields, filter) * total_rows
  end

  defp get_total_complete_cells(fields, filter) do
    fields
    |> Enum.filter(filter)
    |> Enum.reduce(0, fn {_key, field_stats}, acc -> acc + field_stats.count end)
  end

  defp is_required?({_key, count_map}) do
    count_map.required == true
  end

  defp is_optional?({_key, count_map}) do
    count_map.required != true
  end
end
