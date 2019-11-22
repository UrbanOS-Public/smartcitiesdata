defmodule Estuary.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @spec start(any, any) :: {:error, any} | {:ok, pid}
  def start(_type, _args) do
    children = [
      # Starts a worker by calling: Estuary.Worker.start_link(arg)
      Estuary.Worker,
      {Elsa.Supervisor, elsa_args()}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Estuary.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp elsa_args do
    start_options = [
      endpoints: [localhost: 9092],
      connection: :estuary_elsa_supervisor,
      consumer: [
        topic: "Topic1",
        partition: 0,
        begin_offset: :earliest,
        handler: Estuary.MessageHandler
      ]
    ]

    start_options
  end
end
