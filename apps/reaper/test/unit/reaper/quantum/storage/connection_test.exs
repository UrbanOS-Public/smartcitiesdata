defmodule Reaper.Quantum.Storage.ConnectionTest do
  use ExUnit.Case
  use Placebo
  import TestHelper, only: [assert_down: 1]

  alias Reaper.Quantum.Storage.Connection

  setup do
    Process.flag(:trap_exit, true)

    :ok
  end

  test "attempts to start redis" do
    allow Redix.start_link(any()), return: {:ok, :pid}

    {:ok, pid} = Connection.start_link(host: "localhost")
    on_exit(fn -> assert_down(pid) end)

    assert_called Redix.start_link(
                    host: "localhost",
                    name: :reaper_quantum_storage_redix,
                    timeout: 10_000,
                    sync_connect: true,
                    exit_on_disconnection: true
                  )
  end

  test "will delay and stop when redix returns error" do
    allow Redix.start_link(any()), return: {:error, :reason}

    assert_time(2, fn ->
      {:error, :reason} = Connection.start_link(host: "localhost")
    end)
  end

  test "will delay if redis throws an exit signal" do
    allow Redix.start_link(any()), exec: fn _ -> exit(:reason) end

    assert_time(2, fn ->
      {:error, :reason} = Connection.start_link(host: "localhost")
    end)
  end

  test "will delay if redis exits after starting" do
    allow Redix.start_link(any()), return: {:ok, :pid}
    {:ok, pid} = Connection.start_link(host: "localhost")
    on_exit(fn -> assert_down(pid) end)
    ref = Process.monitor(pid)

    assert_time(2, fn ->
      send(pid, {:EXIT, :pid, :reason})
      assert_receive {:DOWN, ^ref, _, _, _}, 3_000
    end)
  end

  defp assert_time(minimum, unit \\ :second, function) do
    start_time = NaiveDateTime.utc_now()
    function.()
    end_time = NaiveDateTime.utc_now()

    assert minimum <= NaiveDateTime.diff(end_time, start_time, unit)
  end
end
