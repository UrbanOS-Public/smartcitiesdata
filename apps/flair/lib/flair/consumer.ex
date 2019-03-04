defmodule Flair.Consumer do
  use GenStage

  alias Flair.PrestoClient

  # CLIENT
  def start_link(args \\ nil) do
    GenStage.start_link(__MODULE__, args, name: __MODULE__)
  end

  # SERVER
  def init(_args) do
    {:consumer, :any}
  end

  def handle_events(events, _from, state) do
    # events |> Enum.into(Map.new()) |> IO.inspect(label: "#{inspect(self())} EVENTS")

    events
    |> Enum.map(fn {dataset_id, stats_map} ->
      Enum.map(stats_map, fn {{app, label}, stats} ->
        %{
          app: app,
          label: label
        }
        |> Map.merge(stats)
        |> Map.put(:dataset_id, dataset_id)
      end)
    end)
    |> List.flatten()
    |> Enum.map(&PrestoClient.values_statement/1)
    |> Enum.join(", ")
    |> PrestoClient.create_insert_statement()
    |> PrestoClient.execute()
    |> IO.inspect(label: "#{inspect(self())} EVENTS")

    {:noreply, [], state}
  end
end
