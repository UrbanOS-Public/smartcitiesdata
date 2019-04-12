defmodule DiscoveryApiWeb.DatasetPrestoQueryService do
  @moduledoc false

  def preview(dataset) do
    "select * from #{dataset} limit 50"
    |> Prestige.execute(rows_as_maps: true)
    |> Prestige.prefetch()
  end

  def preview_columns(dataset) do
    "show columns from #{dataset}"
    |> Prestige.execute()
    |> Prestige.prefetch()
    |> Enum.map(fn [column_name | _tail] -> column_name end)
  end
end
