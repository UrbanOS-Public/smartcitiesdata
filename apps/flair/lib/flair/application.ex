defmodule Flair.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      kaffe_group_supervisor()
    ]

    opts = [strategy: :one_for_one, name: Flair.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def kaffe_group_supervisor do
    %{
      id: Kaffe.GroupMemberSupervisor,
      start: {Kaffe.GroupMemberSupervisor, :start_link, []},
      type: :supervisor
    }
  end
end
