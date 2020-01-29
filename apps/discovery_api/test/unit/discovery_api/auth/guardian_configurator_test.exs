defmodule DiscoveryApi.Auth.GuardianConfiguratorTest do
  use ExUnit.Case

  alias DiscoveryApi.Auth.GuardianConfigurator

  @issuer "http://my-issuer.com"

  describe "with default auth provider" do
    setup do
      original_guardian_config = Application.get_env(:discovery_api, DiscoveryApi.Auth.Guardian)
      Application.put_env(:discovery_api, DiscoveryApi.Auth.Guardian, secret_key: "super secret", issuer: nil, secret_fetcher: "thing")

      GuardianConfigurator.configure()

      on_exit(fn ->
        Application.put_env(:discovery_api, DiscoveryApi.Auth.Guardian, original_guardian_config)
      end)

      :ok
    end

    test "sets the auth provider property" do
      assert "default" == Application.get_env(:discovery_api, :auth_provider)
    end

    test "preserves the pre-set secret key" do
      assert "super secret" ==
               Application.get_env(:discovery_api, DiscoveryApi.Auth.Guardian)
               |> Keyword.get(:secret_key)
    end

    test "verifies issuer" do
      assert true ==
               Application.get_env(:discovery_api, DiscoveryApi.Auth.Guardian)
               |> Keyword.get(:verify_issuer)
    end

    test "sets issuer to 'discovery_api'" do
      assert "discovery_api" ==
               Application.get_env(:discovery_api, DiscoveryApi.Auth.Guardian)
               |> Keyword.get(:issuer)
    end

    test "clears secret fetcher" do
      assert nil ==
               Application.get_env(:discovery_api, DiscoveryApi.Auth.Guardian)
               |> Keyword.get(:secret_fetcher)
    end
  end

  describe "with auth0 auth provider" do
    setup do
      original_guardian_config = Application.get_env(:discovery_api, DiscoveryApi.Auth.Guardian)
      Application.put_env(:discovery_api, DiscoveryApi.Auth.Guardian, secret_key: "super secret", issuer: @issuer)

      GuardianConfigurator.configure("auth0")

      on_exit(fn ->
        Application.put_env(:discovery_api, DiscoveryApi.Auth.Guardian, original_guardian_config)
      end)

      :ok
    end

    test "sets the auth provider property" do
      assert "auth0" == Application.get_env(:discovery_api, :auth_provider)
    end

    test "has the correct algorithms" do
      assert ["RS256"] ==
               Application.get_env(:discovery_api, DiscoveryApi.Auth.Guardian)
               |> Keyword.get(:allowed_algos)
    end

    test "sets the correct secret fetcher" do
      assert DiscoveryApi.Auth.Auth0.SecretFetcher ==
               Application.get_env(:discovery_api, DiscoveryApi.Auth.Guardian)
               |> Keyword.get(:secret_fetcher)
    end

    test "verifies issuer" do
      assert true ==
               Application.get_env(:discovery_api, DiscoveryApi.Auth.Guardian)
               |> Keyword.get(:verify_issuer)
    end

    test "clears secret key" do
      assert nil ==
               Application.get_env(:discovery_api, DiscoveryApi.Auth.Guardian)
               |> Keyword.get(:secret_key)
    end

    test "does not alter issuer" do
      assert @issuer ==
               Application.get_env(:discovery_api, DiscoveryApi.Auth.Guardian)
               |> Keyword.get(:issuer)
    end
  end
end
