defmodule DiscoveryApiWeb.DatasetPrestoQueryService do
  @default_opts [catalog: "hive", schema: "default", by_names: true]

  def preview(dataset) do
    Prestige.execute("select * from #{dataset} limit 50", @default_opts)
    |> Prestige.prefetch()
  end
end
