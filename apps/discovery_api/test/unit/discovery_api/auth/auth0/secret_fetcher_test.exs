defmodule DiscoveryApi.Auth.Auth0.SecretFetcherTest do
  use ExUnit.Case
  use Placebo
  alias DiscoveryApi.Auth.Auth0.SecretFetcher
  alias DiscoveryApi.Auth.Auth0.CachedJWKS

  @jwks DiscoveryApi.Test.AuthHelper.valid_jwks()
  @last_key Map.get(@jwks, "keys") |> List.last()
  @last_key_id Map.get(@last_key, "kid")

  describe "fetch verifying secret" do
    test "retrieves secret from cached jwks when available" do
      CachedJWKS.set(@jwks)

      actual = SecretFetcher.fetch_verifying_secret(:irrelevant, %{"kid" => @last_key_id}, :nope)

      expected = {:ok, @last_key |> JOSE.JWK.from()}
      assert expected == actual
    end

    test "fetches secret from jwks endpoint when not cached" do
      CachedJWKS.delete()
      jwks_response = {:ok, %{body: Jason.encode!(@jwks)}}
      allow(HTTPoison.get(Application.get_env(:discovery_api, :jwks_endpoint)), return: jwks_response)

      actual = SecretFetcher.fetch_verifying_secret(:irrelevant, %{"kid" => @last_key_id}, :nope)

      expected = {:ok, @last_key |> JOSE.JWK.from()}
      assert expected == actual
    end

    test "caches secret from jwks endpoint after fetching" do
      CachedJWKS.delete()
      jwks_response = {:ok, %{body: Jason.encode!(@jwks)}}
      allow(HTTPoison.get(Application.get_env(:discovery_api, :jwks_endpoint)), return: jwks_response)

      SecretFetcher.fetch_verifying_secret(:irrelevant, %{"kid" => @last_key_id}, :nope)

      assert @jwks == CachedJWKS.get()
    end

    test "returns error when jwks endpoint returns error" do
      CachedJWKS.delete()
      jwks_response = {:error, :bad_things_happened}
      allow(HTTPoison.get(Application.get_env(:discovery_api, :jwks_endpoint)), return: jwks_response)

      actual = SecretFetcher.fetch_verifying_secret(:irrelevant, %{"kid" => @last_key_id}, :nope)

      expected = {:error, :bad_things_happened}
      assert expected == actual
    end

    test "returns error when jwks endpoint doesn't have key" do
      CachedJWKS.delete()
      jwks_response = {:ok, %{body: Jason.encode!(@jwks)}}
      allow(HTTPoison.get(Application.get_env(:discovery_api, :jwks_endpoint)), return: jwks_response)

      actual = SecretFetcher.fetch_verifying_secret(:irrelevant, %{"kid" => "unknownKid"}, :nope)

      expected = {:error, "no key for kid: unknownKid"}
      assert expected == actual
    end

    test "fetches secret from jwks endpoint when cached jwks does not have key" do
      cached_jwks_without_key = %{"keys" => []}
      CachedJWKS.set(cached_jwks_without_key)

      jwks_response = {:ok, %{body: Jason.encode!(@jwks)}}
      allow(HTTPoison.get(Application.get_env(:discovery_api, :jwks_endpoint)), return: jwks_response)

      actual = SecretFetcher.fetch_verifying_secret(:irrelevant, %{"kid" => @last_key_id}, :nope)

      expected = {:ok, @last_key |> JOSE.JWK.from()}
      assert expected == actual
    end
  end
end
