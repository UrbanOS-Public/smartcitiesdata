defmodule Reaper.Scheduler.Supervisor do
  @moduledoc """
  Supervisor that manages all quantum related processes.
  """
  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    children = [
      {Reaper.Quantum.Storage, Reaper.redis_quantum_storage()},
      Reaper.Scheduler
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end
