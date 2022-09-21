defmodule Andi.Application do
  @moduledoc false

  use Application
  use Properties, otp_app: :andi

  require Logger

  @instance_name Andi.instance_name()

  getter(:brook, generic: true)
  getter(:kafka_endpoints, generic: true)
  getter(:dead_letter_topic, generic: true)
  getter(:secrets_endpoint, generic: true)

  def start(_type, _args) do
    set_guardian_db_config()

    children =
      [
        {Phoenix.PubSub, [name: Andi.PubSub, adapter: Phoenix.PubSub.PG2]},
        AndiWeb.Endpoint,
        ecto_repo(),
        private_access_processes()
      ]
      |> TelemetryEvent.config_init_server(@instance_name)
      |> List.flatten()

    set_auth0_credentials()
    set_aws_keys()
    set_other_env_variables()

    opts = [strategy: :one_for_one, name: Andi.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp private_access_processes() do
    if Andi.private_access?() do
      [
        guardian_db_sweeper(),
        {Brook, brook()},
        Andi.DatasetCache,
        Andi.Migration.Migrations,
        Andi.Scheduler,
        elsa()
      ]
    else
      []
    end
  end

  defp elsa() do
    case kafka_endpoints() do
      nil ->
        []

      _ ->
        {Elsa.Supervisor,
         endpoints: kafka_endpoints(),
         name: :andi_elsa,
         connection: :andi_reader,
         group_consumer: [
           name: "andi_reader",
           group: "andi_reader_group",
           topics: [dead_letter_topic()],
           handler: Andi.MessageHandler,
           handler_init_args: [],
           config: [
             begin_offset: :latest
           ]
         ]}
    end
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

  def is_invalid_env_variable(var) do
    is_nil(var) || String.length(var) == 0
  end

  def get_env_variable(var_name, throw_if_absent) do
    var = System.get_env(var_name)

    if is_invalid_env_variable(var) do
      Logger.warn("Required environment variable #{var_name} is nil.")

      if throw_if_absent do
        raise RuntimeError,
          message: "Could not start application, required #{var_name} is nil."
      end
    end

    var
  end

  def set_auth0_credentials() do
    Application.put_env(:ueberauth, Ueberauth.Strategy.Auth0.OAuth,
      domain: get_env_variable("AUTH0_DOMAIN", false),
      client_id: get_env_variable("AUTH0_CLIENT_ID", false),
      client_secret: get_env_variable("AUTH0_CLIENT_SECRET", false)
    )
  end

  def set_aws_keys() do
    Application.put_env(:ex_aws, :access_key_id, get_env_variable("AWS_ACCESS_KEY_ID", true))
    Application.put_env(:ex_aws, :secret_access_key, get_env_variable("AWS_ACCESS_KEY_SECRET", true))
  end

  def set_other_env_variables() do
    Application.put_env(:andi, :logo_url, get_logo_url())
  end

  def get_logo_url() do
    env_url = get_env_variable("ANDI_LOGO_URL", false)

    case is_invalid_env_variable(env_url) do
      false -> env_url
      true -> "/images/UrbanOS.svg"
    end
  end

  defp guardian_db_sweeper do
    Application.get_env(:andi, Guardian.DB)
    |> case do
      nil ->
        []

      _config ->
        Supervisor.Spec.worker(Guardian.DB.Token.SweeperServer, [])
    end
  end

  defp set_guardian_db_config do
    Application.get_env(:andi, Guardian.DB)
    |> case do
      nil ->
        []

      config ->
        Application.put_env(:guardian, Guardian.DB, config)
    end
  end
end
