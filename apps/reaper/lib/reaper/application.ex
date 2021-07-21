defmodule Reaper.Application do
  @moduledoc false

  use Application
  use Properties, otp_app: :reaper

  require Logger

  @instance_name Reaper.instance_name()

  getter(:brook, generic: true)
  getter(:secrets_endpoint, generic: true)

  def redis_client(), do: :reaper_redix

  def start(_type, _args) do
    children =
      [
        libcluster(),
        {Reaper.Horde.Registry, keys: :unique},
        {Reaper.Cache.Registry, keys: :unique},
        Reaper.Horde.Supervisor,
        {Reaper.Horde.NodeListener, hordes: [Reaper.Horde.Supervisor, Reaper.Horde.Registry, Reaper.Cache.Registry]},
        Reaper.Cache.AuthCache,
        redis(),
        Reaper.Migrations,
        brook_instance(),
        Reaper.Scheduler.Supervisor,
        Reaper.Init
      ]
      |> TelemetryEvent.config_init_server(@instance_name)
      |> List.flatten()

    fetch_and_set_hosted_file_credentials()

    opts = [strategy: :one_for_one, name: Reaper.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp libcluster() do
    case Application.get_env(:libcluster, :topologies) do
      nil -> []
      topology -> {Cluster.Supervisor, [topology, [name: Cluster.ClusterSupervisor]]}
    end
  end

  defp redis() do
    Application.get_env(:redix, :args, [])
    |> case do
      nil -> []
      redix_args -> {Redix, Keyword.put(redix_args, :name, redis_client())}
    end
  end

  defp brook_instance() do
    config = brook() |> Keyword.put(:instance, @instance_name)
    {Brook, config}
  end

  def get_env_variable(var_name) do
    var = System.get_env(var_name)

    if is_nil(var) || String.length(var) == 0 do
      Logger.warn("Required environment variable #{var_name} is nil.")
      raise RuntimeError,
          message: "Could not start application, required #{var_name} is not set."
    end
    var
  end

  defp fetch_and_set_hosted_file_credentials do
      
  Application.put_env(:ex_aws, :access_key_id, get_env_variable("AWS_ACCESS_KEY_ID"))
  Application.put_env(
    :ex_aws,
    :secret_access_key,
    get_env_variable("AWS_ACCESS_KEY_SECRET")
  )

  end
end
