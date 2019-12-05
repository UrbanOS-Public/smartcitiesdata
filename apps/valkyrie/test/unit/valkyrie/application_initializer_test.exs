defmodule Application.InitializerTest do
  use ExUnit.Case

  @dynamic_supervisor :test_dynamic_supervisor

  defmodule Initter do
    use Application.Initializer

    def do_init(opts) do
      if Keyword.has_key?(opts, :pid) do
        send(Keyword.get(opts, :pid), :do_init_called)
      end

      Keyword.get(opts, :return, :ok)
    end
  end

  setup do
    {:ok, dyn_sup} = DynamicSupervisor.start_link(strategy: :one_for_one, name: @dynamic_supervisor)

    on_exit(fn -> assert_down(dyn_sup) end)

    [dynamic_supervisor: dyn_sup]
  end

  test "should run initialization when started" do
    {:ok, pid} = Initter.start_link(pid: self(), monitor: @dynamic_supervisor)
    on_exit(fn -> assert_down(pid) end)

    assert_receive :do_init_called
  end

  test "should stop if do_init returns an error" do
    assert {:error, :some_reason} == Initter.start_link(return: {:error, :some_reason}, monitor: @dynamic_supervisor)
  end

  test "should monitor external process and re-init if it goes down", %{dynamic_supervisor: dyn_sup} do
    {:ok, pid} = Initter.start_link(pid: self(), monitor: @dynamic_supervisor)
    on_exit(fn -> assert_down(pid) end)

    assert_receive :do_init_called

    assert_down(dyn_sup)
    Process.sleep(500)

    refute_receive :do_init_called
    {:ok, dyn_sup} = DynamicSupervisor.start_link(strategy: :one_for_one, name: @dynamic_supervisor)
    on_exit(fn -> assert_down(dyn_sup) end)

    assert_receive :do_init_called
  end

  defp assert_down(pid) do
    if Process.alive?(pid) do
      Process.unlink(pid)
      ref = Process.monitor(pid)
      Process.exit(pid, :shutdown)
      assert_receive {:DOWN, ^ref, _, _, _}
    end
  end
end
