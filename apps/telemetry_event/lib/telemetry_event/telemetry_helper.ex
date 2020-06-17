defmodule TelemetryEvent.TelemetryHelper do
  @moduledoc false
  alias Telemetry.Metrics

  def metrics,
    do: [
      Metrics.counter("events_handled.count", tags: [:app, :author, :dataset_id, :event_type])
    ]

  def add_event_count(options \\ []),
    do:
      :telemetry.execute([:events_handled], %{}, %{
        app: Keyword.get(options, :app),
        author: Keyword.get(options, :author),
        dataset_id: Keyword.get(options, :dataset_id),
        event_type: Keyword.get(options, :event_type)
      })
end
