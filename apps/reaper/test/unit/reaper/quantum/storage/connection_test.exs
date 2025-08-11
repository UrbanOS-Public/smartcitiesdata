defmodule Reaper.Quantum.Storage.ConnectionTest do
  use ExUnit.Case, async: false
  import Mox
  import TestHelper, only: [assert_down: 1]

  alias Reaper.Quantum.Storage.Connection

  setup :verify_on_exit!
  setup :set_mox_from_context

  setup do
    Process.flag(:trap_exit, true)
    :ok
  end

  test "attempts to start redis" do
    expect(RedixMock, :start_link, fn opts ->
      assert Keyword.get(opts, :host) == "localhost"
      assert Keyword.get(opts, :name) == :reaper_quantum_storage_redix
      assert Keyword.get(opts, :timeout) == 10_000
      assert Keyword.get(opts, :sync_connect) == true
      assert Keyword.get(opts, :exit_on_disconnection) == true
      {:ok, :pid}
    end)

    {:ok, pid} = Connection.start_link(host: "localhost")
    on_exit(fn -> assert_down(pid) end)
  end

  test "will delay and stop when redix returns error" do
    expect(RedixMock, :start_link, fn _ -> {:error, :reason} end)

    assert_time(2, fn ->
      {:error, :reason} = Connection.start_link(host: "localhost")
    end)
  end

  test "will delay if redis throws an exit signal" do
    expect(RedixMock, :start_link, fn _ -> exit(:reason) end)

    assert_time(2, fn ->
      {:error, :reason} = Connection.start_link(host: "localhost")
    end)
  end

  test "will delay if redis exits after starting" do
    expect(RedixMock, :start_link, 1, fn _ -> {:ok, self()} end)
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
