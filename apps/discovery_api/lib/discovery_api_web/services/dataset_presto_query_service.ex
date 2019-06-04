defmodule DiscoveryApiWeb.DatasetPrestoQueryService do
  @moduledoc """
  Module for executing specific queries against presto
  """

  def preview(dataset_system_name) do
    "select * from #{dataset_system_name} limit 50"
    |> Prestige.execute(rows_as_maps: true)
    |> Prestige.prefetch()
  end

  def preview_columns(dataset_system_name) do
    "show columns from #{dataset_system_name}"
    |> Prestige.execute()
    |> Prestige.prefetch()
    |> Enum.map(fn [column_name | _tail] -> column_name end)
  end
end
