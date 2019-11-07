defmodule Reaper.RunTaskTest do
  use ExUnit.Case

  defmodule Runner do
    def run() do
      raise "something blew up"
    end
  end

  describe "run_task" do
    setup do
      {:ok, pid} = Horde.Registry.start_link(keys: :unique, name: Reaper.Horde.Registry)

      on_exit(fn ->
        ref = Process.monitor(pid)
        Process.exit(pid, :normal)
        assert_receive {:DOWN, ^ref, _, _, _}
      end)

      :ok
    end

    @tag :capture_log
    test "should rescue all exceptions and delay for 2 seconds before stopping" do
      Process.flag(:trap_exit, true)

      start = DateTime.utc_now()
      {:ok, pid} = Reaper.RunTask.start_link(name: :test, mfa: {Runner, :run, []}, completion_callback: fn -> :ok end)
      expected_reason = RuntimeError.exception(message: "something blew up")
      assert_receive {:EXIT, ^pid, ^expected_reason}, 2_000
      stop = DateTime.utc_now()

      assert DateTime.diff(stop, start) >= 1
    end
  end
end
