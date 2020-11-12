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

  defp fetch_and_set_hosted_file_credentials do
    endpoint = secrets_endpoint()

    if is_nil(endpoint) || String.length(endpoint) == 0 do
      Logger.warn("No secrets endpoint. Reaper will not be able to upload hosted files.")
      []
    else
      case Reaper.SecretRetriever.retrieve_aws_keys() do
        nil ->
          raise RuntimeError,
            message: "Could not start application, failed to retrieve AWS keys from Vault."

        {:error, error} ->
          raise RuntimeError,
            message: "Could not start application, encountered error while retrieving AWS keys: #{error}"

        {:ok, creds} ->
          Application.put_env(:ex_aws, :access_key_id, Map.get(creds, "aws_access_key_id"))

          Application.put_env(
            :ex_aws,
            :secret_access_key,
            Map.get(creds, "aws_secret_access_key")
          )
      end
    end
  end
end
