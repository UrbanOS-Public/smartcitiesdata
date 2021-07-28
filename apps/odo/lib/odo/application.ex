defmodule Odo.Application do
  @moduledoc false

  require Logger
  use Application
  use Properties, otp_app: :odo

  @instance_name Odo.instance_name()

  getter(:brook, generic: true)
  getter(:secrets_endpoint, generic: true)

  def start(_type, _args) do
    children =
      [
        {Task.Supervisor, name: Odo.TaskSupervisor, max_restarts: 120, max_seconds: 60},
        brook_instance(),
        Odo.Init
      ]
      |> TelemetryEvent.config_init_server(@instance_name)
      |> List.flatten()

    fetch_and_set_hosted_file_credentials()

    opts = [strategy: :one_for_one, name: Odo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp brook_instance() do
    case brook() do
      nil -> []
      config -> {Brook, Keyword.put(config, :instance, @instance_name)}
    end
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

  defp fetch_and_set_hosted_file_credentials() do
    Application.put_env(:ex_aws, :access_key_id, get_env_variable("AWS_ACCESS_KEY_ID"))
    Application.put_env(:ex_aws, :secret_access_key, get_env_variable("AWS_ACCESS_KEY_SECRET"))
  end
end
