defmodule Reaper.RunTask do
  @moduledoc false
  use GenServer, restart: :temporary
  use Properties, otp_app: :reaper

  require Logger

  getter(:task_delay_on_failure, generic: true, default: 10_000)
  @instance_name Reaper.instance_name()

  def start_link(args) do
    name = Keyword.fetch!(args, :name)
    GenServer.start_link(__MODULE__, args, max_restarts: 1, max_seconds: 2, name: via_tuple(name))
  end

  def init(args) do
    {:ok, Enum.into(args, %{}), {:continue, :run_task}}
  end

  def handle_continue(:run_task, %{mfa: {module, function, args} = info, completion_callback: callback} = state) do
    apply(module, function, args) |> callback.()
    {:stop, :normal, state}
  rescue
    e ->
      Logger.error("Reaper Task Failed with error: #{inspect(e)}")
      DeadLetter.process(["Unknown"], "Unknown", inspect(info), Atom.to_string(@instance_name), reason: inspect(e))

      reraise e, __STACKTRACE__
  end

  def via_tuple(name) do
    {:via, Horde.Registry, {Reaper.Horde.Registry, name}}
  end
end
