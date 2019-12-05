defmodule Pipeline.Application do
  @moduledoc false
  use Application

  def start(_, _) do
    children = [
      {DynamicSupervisor, strategy: :one_for_one, name: Pipeline.DynamicSupervisor},
      {Registry, name: Pipeline.Registry, keys: :unique}
    ]

    opts = [strategy: :one_for_one, name: Pipeline.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
