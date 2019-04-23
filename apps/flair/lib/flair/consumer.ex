defmodule Flair.Consumer do
  @moduledoc false

  use GenStage

  alias Flair.PrestoClient

  def start_link(args \\ nil) do
    GenStage.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    {:consumer, :any}
  end

  {"123",
   [
     %{
       dataset_id: "123",
       field: "id",
       records: 3,
       schema_version: "0.1",
       valid_values: 0
     }
   ]}

  def handle_events([{id, [%{valid_values: valid_values}]}] = events, _from, state) do
    events
    |> convert_events()
    |> PrestoClient.generate_quality_statement_from_events()
    |> PrestoClient.execute()

    {:noreply, [], state}
  end

  def handle_events(events, _from, state) do
    events
    |> convert_events()
    |> PrestoClient.generate_timing_statement_from_events()
    |> PrestoClient.execute()

    {:noreply, [], state}
  end

  defp convert_events([{id, [%{valid_values: valid_values}]}] = events) do
    events
    |> Enum.map(fn {id, event} -> event end)
    |> List.flatten()
  end

  defp convert_events(events) do
    events
    |> Enum.map(fn {dataset_id, stats_map} ->
      Enum.map(stats_map, fn {{app, label}, stats} ->
        %{
          dataset_id: dataset_id,
          app: app,
          label: label,
          timestamp: get_time(),
          stats: stats
        }
      end)
    end)
    |> List.flatten()
  end

  defp get_time do
    DateTime.utc_now() |> DateTime.to_unix()
  end
end
