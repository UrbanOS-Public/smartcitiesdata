defmodule Estuary.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    [
      Estuary.Quantum.Scheduler,
      {Estuary.InitServer, []}
    ]
    |> List.flatten()
    |> Supervisor.start_link(strategy: :one_for_one, name: Estuary.Supervisor)
  end
end
