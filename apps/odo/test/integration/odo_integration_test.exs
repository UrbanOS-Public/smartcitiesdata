defmodule Odo.IntegrationTest do
  use ExUnit.Case

  test "does nothing" do
    # This test is to allow the umbrella CI script that runs
    # integration tests across all sub-applications to run in the
    # Odo app's context without re-running unit tests (and breaking)
    :ok
  end
end
