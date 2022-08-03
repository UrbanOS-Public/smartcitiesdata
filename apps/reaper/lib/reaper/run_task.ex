defmodule Reaper.RunTask do
  @moduledoc false
  use GenServer, restart: :transient
  use Properties, otp_app: :reaper

  getter(:task_delay_on_failure, generic: true, default: 10_000)

  def start_link(args) do
    name = Keyword.fetch!(args, :name)
    GenServer.start_link(__MODULE__, args, max_restarts: 10, max_seconds: 2, name: via_tuple(name))
  end

  def init(args) do
    {:ok, Enum.into(args, %{}), {:continue, :run_task}}
  end

  def handle_continue(:run_task, %{mfa: {module, function, args}, completion_callback: callback} = state) do
    apply(module, function, args) |> callback.()
    {:stop, :normal, state}
  rescue
    e ->
      task_delay_on_failure()
      |> Process.sleep()

      {:stop, e, state}
  end

  def via_tuple(name) do
    {:via, Horde.Registry, {Reaper.Horde.Registry, name}}
  end
end
