defmodule Andi.TelemetryHelper do
  @moduledoc false
  alias Telemetry.Metrics

  def metrics,
    do: [
      Metrics.counter("events_handled.count", tags: [:app, :author, :topic, :event_type])
    ]

  def add_event_count(event_type),
    do:
      :telemetry.execute([:events_handled], %{}, %{
        app: "andi",
        author: "andi",
        topic: Application.get_env(:andi, :topic),
        event_type: "event_type"
      })
end
