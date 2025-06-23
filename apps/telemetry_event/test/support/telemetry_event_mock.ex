defmodule TelemetryEvent.Mock do
  @moduledoc """
  A mock implementation of `TelemetryEvent.Behaviour` for testing purposes.

  This module captures telemetry events in memory, allowing tests to verify
  that events were emitted with the expected parameters.
  """
  @behaviour TelemetryEvent.Behaviour

  use Agent

  @doc """
  Starts the mock agent and sets it as the current implementation.
  """
  def start_link(_opts \\ []) do
    Agent.start_link(fn -> [] end, name: __MODULE__)
  end

  @doc """
  Returns all captured events in the order they were received.
  """
  def events do
    Agent.get(__MODULE__, & &1)
  end

  @doc """
  Clears all captured events.
  """
  def clear_events do
    Agent.update(__MODULE__, fn _ -> [] end)
  end

  @doc """
  Asserts that an event with the given name was captured.

  Returns the event data if found, raises if not found.
  """
  def assert_event(event_name) do
    case Enum.find(events(), &match?({^event_name, _, _}, &1)) do
      nil -> raise "Event #{inspect(event_name)} not found in captured events: #{inspect(events())}"
      event -> event
    end
  end

  @impl true
  def add_event_metrics(event_metadata, event_name, measurements) do
    event = {event_name, event_metadata, measurements}
    Agent.update(__MODULE__, &[event | &1])
    :ok
  end
end
