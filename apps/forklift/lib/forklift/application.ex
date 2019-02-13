defmodule Forklift.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: Forklift.Registry}
    ]

    kaffe_group_supervisor = %{
      id: Kaffe.GroupMemberSupervisor,
      start: {Kaffe.GroupMemberSupervisor, :start_link, []},
      type: :supervisor
    }

    children =
      case Mix.env() do
        :test -> children
        _env -> children ++ [kaffe_group_supervisor]
      end

    opts = [strategy: :one_for_one, name: Forklift.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
