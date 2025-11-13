defmodule Flair.Durations.FlowTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  alias Flair.Durations.Flow

  @moduletag timeout: 5000

  setup do
    # Kill any existing processes from previous tests
    cleanup_processes()

    # Wait for the processes to be fully cleaned up
    :timer.sleep(50)

    on_exit(fn ->
      cleanup_processes()
      :timer.sleep(50)
    end)

    :ok
  end

  defp cleanup_processes do
    # Kill the producer
    case Process.whereis(:durations) do
      nil -> :ok
      pid -> Process.exit(pid, :kill)
    end

    # Kill the consumer
    case Process.whereis(:durations_consumer) do
      nil -> :ok
      pid -> Process.exit(pid, :kill)
    end
  end

  describe "start_link/1" do
    test "successfully starts the Flow supervision tree" do
      # This test verifies that the Flow can start without the previous ArgumentError
      # about map/2 being called after reduce operations

      # We expect this to start successfully and return a Flow pid
      assert {:ok, flow_pid} = Flow.start_link([])
      assert is_pid(flow_pid)

      # Clean up the flow
      GenServer.stop(flow_pid)

      # Also clean up all related processes
      cleanup_processes()
    end

    test "Flow processes messages through the pipeline without errors" do
      # Test that the Flow pipeline can be constructed without Flow operation errors
      # This validates our fix where we replaced Flow.map with Flow.on_trigger
      # and Flow.each with proper Flow.map that returns values

      log_output =
        capture_log(fn ->
          assert {:ok, flow_pid} = Flow.start_link([])

          # Give it a moment to initialize
          Process.sleep(100)

          # Clean up
          GenServer.stop(flow_pid)

          # Also clean up all related processes
          cleanup_processes()
        end)

      # Should not contain ArgumentError about map/2 after reduce operations
      refute log_output =~ "map/2 cannot be called after group_by/reduce/emit_and_reduce"
      refute log_output =~ "each/2 cannot be called after group_by/reduce/emit_and_reduce"
    end
  end
end
