Application.load(:reaper)

Application.spec(:reaper, :applications)
|> Enum.each(&Application.ensure_all_started/1)

Mox.defmock(Providers.Echo, for: Providers.Provider)

Application.ensure_all_started(:bypass)

ExUnit.start(exclude: [:skip])

defmodule TestHelper do
  use ExUnit.Case
  import Mox
  require Logger

  def start_horde() do
    children = [
      {Reaper.Horde.Registry, [name: Reaper.Horde.Registry, keys: :unique]},
      {Reaper.Cache.Registry, [name: Reaper.Cache.Registry, keys: :unique]},
      {Reaper.Horde.Supervisor, [name: Reaper.Horde.Supervisor, strategy: :one_for_one]}
    ]

    {:ok, supervisor} = Supervisor.start_link(children, strategy: :one_for_one, name: Reaper.TestSupervisor)

    on_exit(fn -> assert_down(supervisor) end)
  end

  def assert_down(pid) do
    ref = Process.monitor(pid)
    Process.exit(pid, :shutdown)
    Logger.debug(fn -> "Ensuring that #{inspect(pid)} is down via #{inspect(ref)}" end)
    assert_receive {:DOWN, ^ref, _, _, _}, 2000
  end
end

defmodule TempEnv do
  @moduledoc """
  use TempEnv, [reaper: [property: "value"]]

  Will set the application environment value above in a setup_all block and
  then reset it back to the original in an on_exit function.

  """
  require Logger

  defmacro __using__(opts) do
    quote do
      setup_all do
        original_values = TempEnv.set_app_values(unquote(opts))
        on_exit(fn -> TempEnv.reset_app_values(original_values) end)
        :ok
      end
    end
  end

  def set_app_values(opts) do
    for {app, props} <- opts,
        {prop, value} <- props do
      og = Application.get_env(app, prop)
      Application.put_env(app, prop, value)
      {app, prop, og}
    end
  end

  def reset_app_values(original_values) do
    for {app, prop, og} <- original_values do
      case og do
        nil -> Application.delete_env(app, prop)
        _ -> Application.put_env(app, prop, og)
      end
    end
  end
end
