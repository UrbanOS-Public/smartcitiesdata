defmodule TelemetryEventBehaviour do
  @moduledoc false
  # Mox mock behaviour for TelemetryEvent

  @callback add_event_metrics(any(), list(), map()) :: :ok | {:error, term()}
  @callback config_init_server(any(), any()) :: any()
end
