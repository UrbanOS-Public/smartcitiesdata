defmodule TelemetryEvent do
  @moduledoc false
  alias Telemetry.Metrics

  def metrics,
    do: [
      Metrics.counter("events_handled.count", tags: [:app, :author, :dataset_id, :event_type])
    ]

  def add_event_count(options),
    do:
      :telemetry.execute([:events_handled], %{}, %{
        app: Keyword.fetch!(options, :app),
        author: Keyword.fetch!(options, :author),
        dataset_id: Keyword.get(options, :dataset_id),
        event_type: Keyword.fetch!(options, :event_type)
      })
end
