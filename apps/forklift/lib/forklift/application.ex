defmodule Forklift.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    kaffe_group_supervisor = %{
      id: Kaffe.GroupMemberSupervisor,
      start: {Kaffe.GroupMemberSupervisor, :start_link, []},
      type: :supervisor
    }

    children = [
      {Registry, keys: :unique, name: Forklift.Registry},
      redis(),
      kaffe_group_supervisor
    ]

    opts = [strategy: :one_for_one, name: Forklift.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp redis do
    Application.get_env(:redix, :host)
    |> case do
      nil -> []
      host -> {Redix, host: host, name: :redix}
    end
  end
end
