defmodule Reaper.Application do
  @moduledoc false

  use Application
  require Logger

  def redis_client(), do: :redix

  def start(_type, _args) do
    children =
      [
        libcluster(),
        {Horde.Registry, [name: Reaper.Registry]},
        {Horde.Supervisor, [name: Reaper.Horde.Supervisor, strategy: :one_for_one]},
        {HordeConnector, [supervisor: Reaper.Horde.Supervisor, registry: Reaper.Registry]},
        Reaper.ConfigServer,
        redis(),
        dataset_subscriber()
      ]
      |> List.flatten()

    fetch_and_set_hosted_file_credentials()

    opts = [strategy: :one_for_one, name: Reaper.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp dataset_subscriber() do
    case Application.get_env(:smart_city_registry, :redis) do
      nil -> []
      _ -> {SmartCity.Registry.Subscriber, [message_handler: Reaper.MessageHandler]}
    end
  end

  defp redis do
    Application.get_env(:redix, :host)
    |> case do
      nil -> []
      host -> {Redix, host: host, name: redis_client()}
    end
  end

  defp libcluster do
    case Application.get_env(:libcluster, :topologies) do
      nil -> []
      topology -> {Cluster.Supervisor, [topology, [name: Cluster.ClusterSupervisor]]}
    end
  end

  defp fetch_and_set_hosted_file_credentials do
    if Application.get_env(:reaper, :secrets_endpoint) do
      case Reaper.SecretRetriever.retrieve_aws_keys() do
        nil ->
          raise RuntimeError, message: "Could not start application, failed to retrieve AWS keys from Vault."

        {:error, error} ->
          raise RuntimeError,
            message: "Could not start application, encountered error while retrieving AWS keys: #{error}"

        {:ok, creds} ->
          Application.put_env(:ex_aws, :access_key_id, Map.get(creds, "aws_access_key_id"))
          Application.put_env(:ex_aws, :secret_access_key, Map.get(creds, "aws_secret_access_key"))
      end
    else
      []
    end
  end
end
