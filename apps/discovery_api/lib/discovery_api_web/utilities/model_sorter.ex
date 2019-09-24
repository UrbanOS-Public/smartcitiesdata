defmodule DiscoveryApiWeb.Utilities.ModelSorter do
  @moduledoc """
  Sorts dataset models based on supplied criteria
  """

  @spec sort_models(list(%DiscoveryApi.Data.Model{}), String.t()) :: list(%DiscoveryApi.Data.Model{})
  def sort_models(models, "name_asc") do
    Enum.sort_by(models, fn map -> String.downcase(map.title) end)
  end

  def sort_models(models, "name_desc") do
    Enum.sort_by(models, fn map -> String.downcase(map.title) end, &>=/2)
  end

  def sort_models(models, "last_mod") do
    Enum.sort_by(models, &select_date/1, &date_sorter/2)
  end

  defp select_date(model) do
    case model.sourceType do
      "ingest" -> ensure_valid(model.modifiedDate)
      "stream" -> ensure_valid(model.lastUpdatedDate)
      "remote" -> :remote
      _ -> :invalid
    end
  end

  defp ensure_valid(nil), do: :invalid

  defp ensure_valid(date) do
    cond do
      is_iso_date_time?(date) -> date
      is_iso_date?(date) -> date
      true -> :invalid
    end
  end

  defp is_iso_date_time?(date) do
    case DateTime.from_iso8601(date) do
      {:ok, _date, _offset} -> true
      _ -> false
    end
  end

  defp is_iso_date?(date) do
    case Date.from_iso8601(date) do
      {:ok, _date} -> true
      _ -> false
    end
  end

  defp date_sorter(:remote, _model2), do: false
  defp date_sorter(_model1, :remote), do: true
  defp date_sorter(:invalid, _model2), do: false
  defp date_sorter(_model1, :invalid), do: true
  defp date_sorter(date1, date2), do: date1 >= date2
end
