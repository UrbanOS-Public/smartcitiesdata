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
    var =
      case Application.get_env(:andi, :var_name) do
        nil -> System.get_env(var_name)
        value -> value
      end

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

    Application.put_env(
      :ex_aws,
      :secret_access_key,
      get_env_variable("AWS_ACCESS_KEY_SECRET", true)
    )
  end

  def set_other_env_variables() do
    Application.put_env(:andi, :logo_url, get_logo_url())
    Application.put_env(:andi, :header_text, get_header_text())
    Application.put_env(:andi, :primary_color, get_primary_color())
    Application.put_env(:andi, :secondary_color, get_secondary_color())
    Application.put_env(:andi, :success_color, get_success_color())
    Application.put_env(:andi, :error_color, get_error_color())
    Application.put_env(:andi, :footer_left_side_text, get_footer_left_side_text())
    Application.put_env(:andi, :footer_left_side_link, get_footer_left_side_link())
    Application.put_env(:andi, :custom_fav_icon_base64, get_custom_fav_icon_base64())
    Application.put_env(:andi, :andi_footer_right_links, get_footer_right_links())
    Application.put_env(:andi, :secure_cookie, get_secure_cookie())
  end

  def get_logo_url() do
    get_env_variable("ANDI_LOGO_URL", true)
  end

  def get_header_text() do
    get_env_variable("ANDI_HEADER_TEXT", true)
  end

  def get_primary_color() do
    get_env_variable("ANDI_PRIMARY_COLOR", true)
  end

  def get_secondary_color() do
    get_env_variable("ANDI_SECONDARY_COLOR", true)
  end

  def get_success_color() do
    get_env_variable("ANDI_SUCCESS_COLOR", true)
  end

  def get_error_color() do
    get_env_variable("ANDI_ERROR_COLOR", true)
  end

  def get_custom_fav_icon_base64() do
    # Optional env variable, to display a favicon
    get_env_variable("CUSTOM_FAV_ICON_BASE64", false)
  end

  def get_footer_left_side_text() do
    get_env_variable("ANDI_FOOTER_LEFT_SIDE_TEXT", true)
  end

  def get_footer_left_side_link() do
    get_env_variable("ANDI_FOOTER_LEFT_SIDE_LINK", false)
  end

  def get_footer_right_links() do
    get_env_variable("ANDI_FOOTER_RIGHT_LINKS", true)
  end

  def get_secure_cookie() do
    var = get_env_variable("SECURE_COOKIE", false)

    if var == nil do
      false
    else
      var
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
