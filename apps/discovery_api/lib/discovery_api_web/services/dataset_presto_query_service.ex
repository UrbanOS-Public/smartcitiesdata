defmodule DiscoveryApiWeb.DatasetPrestoQueryService do
  @moduledoc false
  @default_opts [catalog: "hive", schema: "default", by_names: true]

  def preview(dataset) do
    "select * from #{dataset} limit 50"
    |> Prestige.execute(@default_opts)
    |> Prestige.prefetch()
  end
end
