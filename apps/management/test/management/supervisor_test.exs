defmodule Management.SupervisorTest do
  use ExUnit.Case

  defmodule Reg do
    use Management.Registry,
      name: __MODULE__
  end

  defmodule Sup do
    use Management.Supervisor,
      name: __MODULE__

    @impl Management.Supervisor
    def say_my_name(%{type: :agent}) do
      Reg.via(:agent1)
    end

    @impl Management.Supervisor
    def on_start_child(%{type: :agent, initial_state: state}, name) do
      %{
        id: :agent1,
        start: {Agent, :start_link, [fn -> state end, [name: name]]}
      }
    end
  end

  test "something, something, something supervisor" do
    start_supervised(Reg)
    start_supervised(Sup)

    {:ok, pid} = Sup.start_child(%{type: :agent, initial_state: :state})
    assert :state == Agent.get(pid, fn s -> s end)

    assert pid == Reg.whereis(:agent1)

    assert :ok == Sup.terminate_child(%{type: :agent})
    assert false == Process.alive?(pid)
  end
end
