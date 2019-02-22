defmodule Valkyrie.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children =
      [
        kaffe()
      ]
      |> List.flatten()

    opts = [strategy: :one_for_one, name: Valkyrie.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp kaffe do
    kaffe_group_supervisor = %{
      id: Kaffe.GroupMemberSupervisor,
      start: {Kaffe.GroupMemberSupervisor, :start_link, []},
      type: :supervisor
    }

    # Should be replaced with actual logic for when not to start the supervisor
    case Application.get_env(:valkyrie, :env) do
      :test -> []
      _ -> kaffe_group_supervisor
    end
  end
end
