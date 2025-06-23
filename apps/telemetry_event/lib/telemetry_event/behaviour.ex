defmodule TelemetryEvent.Behaviour do
  @moduledoc """
  Defines the behaviour for telemetry event handling.

  This behaviour allows for different implementations of telemetry event handling,
  which is particularly useful for testing and different runtime environments.
  """

  @type event_name :: [atom()]
  @type event_measurements :: map()
  @type event_metadata :: keyword() | map()

  @doc """
  Adds telemetry metrics for the given event.

  ## Parameters
    * `event_metadata` - A keyword list or map containing metadata for the event
    * `event_name` - The name of the event as an atom list (e.g., `[:my_app, :event]`)
    * `measurements` - Optional measurements map for the event

  ## Returns
    * `:ok` on success
    * `{:error, reason}` on failure
  """
  @callback add_event_metrics(
          event_metadata :: event_metadata(),
          event_name :: event_name(),
          measurements :: event_measurements()
        ) :: :ok | {:error, term()}
end
