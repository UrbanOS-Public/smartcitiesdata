defmodule Odo.Application do
  @moduledoc false

  require Logger
  use Application

  def start(_type, _args) do
    Odo.MetricsExporter.setup()

    children =
      [
        {Task.Supervisor, name: Odo.TaskSupervisor, max_restarts: 120, max_seconds: 60},
        brook(),
        Odo.Init,
        metrics()
      ]
      |> List.flatten()

    fetch_and_set_hosted_file_credentials()

    opts = [strategy: :one_for_one, name: Odo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp brook() do
    Application.get_env(:brook, :config)
    |> case do
      nil -> []
      config -> {Brook, config}
    end
  end

  defp fetch_and_set_hosted_file_credentials() do
    endpoint = Application.get_env(:odo, :secrets_endpoint)

    if is_nil(endpoint) || String.length(endpoint) == 0 do
      Logger.warn(
        "No secrets endpoint. Odo will need to explicitly define a secret id and key to interact with the object store"
      )

      []
    else
      case Odo.SecretRetriever.retrieve_objectstore_keys() do
        nil ->
          raise RuntimeError, message: "Could not start application, failed to retrieve credentials from storage"

        {:error, error} ->
          raise RuntimeError,
            message: "Could not start application, encountered error while retrieving credentials: #{error}"

        {:ok, creds} ->
          Application.put_env(:ex_aws, :access_key_id, Map.get(creds, "aws_access_key_id"))
          Application.put_env(:ex_aws, :secret_access_key, Map.get(creds, "aws_secret_access_key"))
      end
    end
  end

  defp metrics() do
    case Application.get_env(:odo, :metrics_port) do
      nil ->
        []

      metrics_port ->
        Plug.Cowboy.child_spec(
          scheme: :http,
          plug: Odo.MetricsExporter,
          options: [port: metrics_port]
        )
    end
  end
end
