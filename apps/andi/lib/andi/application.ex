defmodule Andi.Application do
  @moduledoc false

  use Application
  import Andi

  def start(_type, _args) do
    children =
      [
        AndiWeb.Endpoint,
        ecto_repo(),
        {Brook, Application.get_env(:andi, :brook)},
        Andi.DatasetCache,
        Andi.Migration.Migrations,
        Andi.Scheduler,
        {Elsa.Supervisor,
         endpoints: Application.get_env(:andi, :kafka_endpoints),
         name: :andi_elsa,
         connection: :andi_reader,
         group_consumer: [
           name: "andi_reader",
           group: "andi_reader_group",
           topics: [Application.get_env(:andi, :dead_letter_topic)],
           handler: Andi.MessageHandler,
           handler_init_args: [],
           config: [
             begin_offset: :latest
           ]
         ]}
      ]
      |> TelemetryEvent.config_init_server(instance_name())
      |> List.flatten()

    opts = [strategy: :one_for_one, name: Andi.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp ecto_repo do
    Application.get_env(:andi, Andi.Repo)
    |> case do
      nil -> []
      _ -> Supervisor.Spec.worker(Andi.Repo, [])
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    AndiWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
