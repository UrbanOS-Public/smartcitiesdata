defmodule DiscoveryApi.Auth.GuardianConfiguratorTest do
  use ExUnit.Case

  alias DiscoveryApi.Auth.GuardianConfigurator
  alias DiscoveryApiWeb.Auth.TokenHandler

  @issuer "http://my-issuer.com"

  describe "with auth0 auth provider" do
    setup do
      original_guardian_config = Application.get_env(:discovery_api, TokenHandler)
      Application.put_env(:discovery_api, TokenHandler, secret_key: "super secret", issuer: @issuer)

      GuardianConfigurator.configure()

      on_exit(fn ->
        Application.put_env(:discovery_api, TokenHandler, original_guardian_config)
      end)

      :ok
    end

    test "has the correct algorithms" do
      assert ["RS256"] ==
               Application.get_env(:discovery_api, TokenHandler)
               |> Keyword.get(:allowed_algos)
    end

    test "sets the correct secret fetcher" do
      assert DiscoveryApi.Auth.Auth0.SecretFetcher ==
               Application.get_env(:discovery_api, TokenHandler)
               |> Keyword.get(:secret_fetcher)
    end

    test "verifies issuer" do
      assert true ==
               Application.get_env(:discovery_api, TokenHandler)
               |> Keyword.get(:verify_issuer)
    end

    test "clears secret key" do
      assert nil ==
               Application.get_env(:discovery_api, TokenHandler)
               |> Keyword.get(:secret_key)
    end

    test "does not alter issuer" do
      assert @issuer ==
               Application.get_env(:discovery_api, TokenHandler)
               |> Keyword.get(:issuer)
    end
  end
end
