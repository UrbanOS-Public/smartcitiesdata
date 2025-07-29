defmodule TelemetryEventBehaviour do
  @moduledoc false
  # Mox mock behaviour for TelemetryEvent

  @callback add_event_metrics(any(), any()) :: :ok
  @callback add_event_metrics(any(), any(), any()) :: :ok
end