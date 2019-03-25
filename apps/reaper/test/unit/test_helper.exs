Application.load(:reaper)

Application.spec(:reaper, :applications)
|> Enum.each(&Application.ensure_all_started/1)

Application.ensure_all_started(:bypass)

ExUnit.start(exclude: [:skip])

defmodule TestHelper do
  use ExUnit.Case
  use Placebo
  require Logger

  def start_horde(registry_name, supervisor_name) do
    children = [
      {Horde.Registry, [name: registry_name]},
      {Horde.Supervisor, [name: supervisor_name, strategy: :one_for_one]}
    ]

    {:ok, supervisor} = Supervisor.start_link(children, strategy: :one_for_one, name: Reaper.TestSupervisor)

    on_exit(fn -> assert_down(supervisor) end)
  end

  def assert_down(pid) do
    ref = Process.monitor(pid)
    Logger.debug(fn -> "Ensuring that #{inspect(pid)} is down via #{inspect(ref)}" end)
    assert_receive {:DOWN, ^ref, _, _, _}
  end
end
