defmodule AndiWeb.Helpers.SortingHelpers do
  @moduledoc """
  Helpers for sorting a list of maps by a field. Includes the ability to mix structs into the sorting (at least DateTime)
  """
  def sort_list_by_field(list, field, dir \\ "asc") do
    Enum.sort_by(list, &Map.get(&1, field), &compare(&1, &2, dir))
  end

  defp compare(%DateTime{} = left, %DateTime{} = right, "asc") do
    DateTime.compare(left, right) in [:lt, :eq]
  end

  defp compare(%DateTime{} = left, %DateTime{} = right, "desc") do
    DateTime.compare(left, right) in [:gt, :eq]
  end

  defp compare(%DateTime{} = _left, _right, "asc"), do: true
  defp compare(_left, %DateTime{} = _right, "asc"), do: false
  defp compare(%DateTime{} = _left, _right, "desc"), do: false
  defp compare(_left, %DateTime{} = _right, "desc"), do: true

  defp compare(left, right, "desc") do
    left >= right
  end

  defp compare(left, right, "asc") do
    left <= right
  end
end
