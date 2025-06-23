defmodule DeadLetter.TelemetryEventHelper do
  @moduledoc """
  Test helper for setting up TelemetryEvent.Mock in DeadLetter tests.
  """

  def setup_telemetry_mock(_context) do
    # Start the mock if it's not already started
    case Process.whereis(TelemetryEvent.Mock) do
      nil ->
        {:ok, _pid} = TelemetryEvent.Mock.start_link()
      _ ->
        TelemetryEvent.Mock.clear_events()
    end

    :ok
  end
end
