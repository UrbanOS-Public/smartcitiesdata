defmodule DiscoveryApi.Auth.GuardianConfigurator do
  @moduledoc """
  Configures guardian based on the specified auth provider
  """
  require Logger

  alias DiscoveryApi.Auth.Guardian

  def configure(additional_config \\ []) do
    current_config = Application.get_env(:discovery_api, Guardian)
    new_config = config_for_auth_provider(current_config)

    Application.put_env(:discovery_api, Guardian, Keyword.merge(new_config, additional_config))
  end

  defp config_for_auth_provider(current_config) do
    [
      allowed_algos: ["RS256"],
      issuer: current_config[:issuer],
      secret_fetcher: DiscoveryApi.Auth.Auth0.SecretFetcher,
      verify_issuer: true
    ]
  end
end
