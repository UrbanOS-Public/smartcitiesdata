defmodule DiscoveryApi.Auth.GuardianConfigurator do
  @moduledoc """
  Configures guardian based on the specified auth provider
  """
  require Logger

  alias DiscoveryApi.Auth.Guardian

  def configure(auth_provider \\ "default", additional_config \\ []) do
    Application.put_env(:discovery_api, :auth_provider, auth_provider)

    current_config = Application.get_env(:discovery_api, Guardian)
    new_config = config_for_auth_provider(auth_provider, current_config)

    Application.put_env(:discovery_api, Guardian, Keyword.merge(new_config, additional_config))

    Logger.info("Guardian configured to run wih '#{auth_provider}' auth provider")
  end

  defp config_for_auth_provider(auth_provider, current_config) do
    case auth_provider do
      "auth0" ->
        [
          allowed_algos: ["RS256"],
          issuer: current_config[:issuer],
          secret_fetcher: DiscoveryApi.Auth.Auth0.SecretFetcher,
          verify_issuer: true
        ]

      _ ->
        [
          issuer: "discovery_api",
          secret_key: current_config[:secret_key],
          verify_issuer: true
        ]
    end
  end
end
