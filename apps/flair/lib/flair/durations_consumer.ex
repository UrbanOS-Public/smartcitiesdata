defmodule Flair.DurationsConsumer do
  @moduledoc """
  Consumer is called at the end of a flow; it converts events and then passes them to presto client to be persisted.
  """

  use GenStage

  @table_writer Application.get_env(:flair, :table_writer)
  @table_name Application.get_env(:flair, :table_name_timing, "operational_stats")

  @table_schema [
    %{name: "dataset_id", type: "string"},
    %{name: "app", type: "string"},
    %{name: "label", type: "string"},
    %{name: "timestamp", type: "long"},
    %{
      name: "stats",
      type: "map",
      subSchema: [
        %{name: "count", type: "long"},
        %{name: "min", type: "double"},
        %{name: "max", type: "double"},
        %{name: "std", type: "double"},
        %{name: "average", type: "double"}
      ]
    }
  ]

  def start_link(name, args \\ nil) do
    GenStage.start_link(__MODULE__, args, name: name)
  end

  def init(_args) do
    @table_writer.init(table: @table_name, schema: @table_schema)
    {:consumer, :any}
  end

  def handle_events(events, _from, state) do
    events
    |> convert_events()
    |> @table_writer.write(table: @table_name, schema: @table_schema)

    {:noreply, [], state}
  end

  defp convert_events(events) do
    events
    |> Enum.map(fn {dataset_id, stats_map} ->
      Enum.map(stats_map, fn {{app, label}, stats} ->
        %{
          payload: %{
            "dataset_id" => dataset_id,
            "app" => app,
            "label" => label,
            "timestamp" => get_time(),
            "stats" => stats
          }
        }
      end)
    end)
    |> List.flatten()
  end

  defp get_time do
    DateTime.utc_now() |> DateTime.to_unix()
  end
end
