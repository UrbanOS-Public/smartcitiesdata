defmodule InitializerTest do
  use ExUnit.Case

  defmodule ExampleInit do
    use Initializer,
      name: __MODULE__,
      supervisor: ExampleSupervisor

    def on_start(state) do
      send(state.pid, :on_start)
      {:ok, state}
    end
  end

  setup do
    Process.flag(:trap_exit, true)
    {:ok, sup_pid} = DynamicSupervisor.start_link(strategy: :one_for_one, name: ExampleSupervisor)

    on_exit(fn -> assert_down(sup_pid) end)

    [sup_pid: sup_pid]
  end

  test "runs on_start when initialized" do
    {:ok, pid} = ExampleInit.start_link(pid: self())

    assert_receive :on_start

    assert_down(pid)
  end

  test "reruns on_start when supervisor dies", %{sup_pid: sup_pid} do
    {:ok, pid} = ExampleInit.start_link(pid: self())

    assert_receive :on_start
    assert_down(sup_pid)

    {:ok, sup_pid} = DynamicSupervisor.start_link(strategy: :one_for_one, name: ExampleSupervisor)

    assert_receive :on_start, 1_000

    assert_down(pid)
    assert_down(sup_pid)
  end

  defp assert_down(pid) do
    ref = Process.monitor(pid)
    Process.exit(pid, :kill)
    assert_receive {:DOWN, ^ref, _, _, _}
  end
end
