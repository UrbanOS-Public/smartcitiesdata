defmodule Dlq.Application do
  @moduledoc false
  use Application
  use Properties, otp_app: :dlq

  getter(:init?, default: true)

  def start(_type, _args) do
    opts = [strategy: :one_for_one, name: Dlq.Supervisor]
    Supervisor.start_link(server(), opts)
  end

  defp server() do
    case {init?(), Application.get_env(:dlq, Dlq.Server)} do
      {true, config} when config != nil -> [Dlq.Server]
      _ -> []
    end
  end
end
