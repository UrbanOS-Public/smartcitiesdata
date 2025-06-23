IO.puts("Helper loaded!")

defmodule TelemetryEvent.MyTestHelper do
  @moduledoc """
  Test helpers for working with TelemetryEvent in tests.

  This module provides functions to start and interact with the `TelemetryEvent.Mock`
  in test environments.

  ## Usage

  In your test module:

      defmodule MyTest do
        use ExUnit.Case
        import TelemetryEvent.TestHelper

        setup :setup_telemetry_mock

        test "my test" do
          # Your test code here
          assert_event_captured([:my_event])
        end
      end
  """

  use ExUnit.Case
  alias TelemetryEvent.Mock

  @doc """
  Sets up the TelemetryEvent.Mock for testing.

  This function should be called in the `setup` block of your tests.

  ## Example

      setup :setup_telemetry_mock

  """
  def setup_telemetry_mock(_context) do
    {:ok, _} = start_supervised(Mock)
    :ok = Mock.clear_events()
    :ok
  end

  @doc """
  Returns all captured events.

  Events are returned in the order they were captured, with the most recent first.
  """
  defdelegate captured_events(), to: Mock, as: :events

  @doc """
  Asserts that an event with the given name was captured.

  Raises if the event is not found.

  ## Examples

      # Assert that an event was captured
      assert {:my_event, _metadata, _measurements} = assert_event_captured([:my_app, :my_event])

      # Pattern match on the event data
      assert {:my_event, %{user_id: user_id}, _} = assert_event_captured([:my_app, :my_event])
      assert user_id == "user123"

  Returns the captured event tuple if found.
  """
  defdelegate assert_event_captured(event_name), to: Mock, as: :assert_event

  @doc """
  Clears all captured events.

  Useful for resetting state between test cases.
  """
  defdelegate clear_captured_events(), to: Mock, as: :clear_events
end
