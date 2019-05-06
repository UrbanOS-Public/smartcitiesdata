defmodule Flair.DurationsConsumer do
  @moduledoc """
  Consumer is called at the end of a flow; it converts events and then passess them to presto client to be persisted.
  """

  use GenStage

  alias Flair.PrestoClient

  def start_link(name, args \\ nil) do
    GenStage.start_link(__MODULE__, args, name: name)
  end

  def init(_args) do
    {:consumer, :any}
  end

  def handle_events(events, _from, state) do
    events
    |> convert_events()
    |> PrestoClient.generate_statement_from_events()
    |> PrestoClient.execute()

    {:noreply, [], state}
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
