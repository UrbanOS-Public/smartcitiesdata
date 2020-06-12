defmodule Andi.TelemetryHelper do
  @moduledoc false
  alias Telemetry.Metrics

  def metrics,
    do: [
      Metrics.counter("events_handled.count", tags: [:app, :author, :dataset_id, :event_type])
    ]

  def add_event_count(event_type, dataset_id),
    do:
      :telemetry.execute([:events_handled], %{}, %{
        app: "andi",
        author: "andi",
        dataset_id: dataset_id,
        event_type: event_type
      })
end
