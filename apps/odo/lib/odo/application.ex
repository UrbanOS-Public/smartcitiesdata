defmodule Odo.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false
  use Application

  def start(_type, _args) do
    children =
      [
        {Task.Supervisor, name: Odo.ShapefileTaskSupervisor, max_restarts: 120, max_seconds: 60},
        brook()
      ]
      |> List.flatten()

    opts = [strategy: :one_for_one, name: Odo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp brook do
    Application.get_env(:brook, :config)
    |> case do
      nil -> []
      config -> {Brook, config}
    end
  end
end
