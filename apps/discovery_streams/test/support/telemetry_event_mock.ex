defmodule DiscoveryStreams.TelemetryEventBehaviour do
  @moduledoc false
  # Mox mock behaviour for TelemetryEvent

  @callback add_event_metrics(keyword() | map(), [atom()]) :: :ok | {:error, term()}
  @callback add_event_metrics(keyword() | map(), [atom()], map()) :: :ok | {:error, term()}
end