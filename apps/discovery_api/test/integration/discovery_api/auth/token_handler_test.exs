defmodule DiscoveryApi.Auth.TokenHandlerTest do
  use ExUnit.Case
  use Divo, services: [:"ecto-postgres", :redis, :zookeeper, :kafka]
  use DiscoveryApi.DataCase

  alias DiscoveryApiWeb.Auth.TokenHandler

  describe "after_encode_and_sign/4" do
    test "adds claims to the database, keyed by audience (and jwtid)" do
      resource = :ignored
      claims = claims()
      token = "also_ignored"
      options = []

      {:ok, ^token} = TokenHandler.after_encode_and_sign(
        resource,
        claims,
        token,
        options
      )

      claims_used_to_store_token = TokenHandler.to_storable_claims(claims)

      assert nil != Guardian.DB.Token.find_by_claims(claims_used_to_store_token)
    end

    test "on major failure (missing aud for example), returns error tuple" do
      resource = :ignored
      claims_without_aud = claims()
      |> Map.delete("aud")
      token = "also_ignored"
      options = []

      assert {:error, _} = TokenHandler.after_encode_and_sign(
        resource,
        claims_without_aud,
        token,
        options
      )
    end
  end

  describe "on_verify/3" do
    test "given a missing token and the option to store it, it succeeds" do
      new_claims = claims()
      token = "also_ignored"
      options = [store_token: true]

      assert {:ok, ^new_claims} = TokenHandler.on_verify(
        new_claims,
        token,
        options
      )
    end

    test "given a missing token (revoked or never seen) and no option to store it, it rejects it" do
      new_claims = claims()
      token = "also_ignored"
      options = []

      assert {:error, _} = TokenHandler.on_verify(
        new_claims,
        token,
        options
      )
    end

    test "given an incomplete token, and the option to store, it returns an error tuple" do
      new_claims_without_aud = claims()
      |> Map.delete("aud")
      token = "also_ignored"
      options = [store_token: true]

      assert {:error, _} = TokenHandler.on_verify(
        new_claims_without_aud,
        token,
        options
      )
    end

    test "given an incomplete token, and no option to store, it returns an error tuple" do
      new_claims_without_aud = claims()
      |> Map.delete("aud")
      token = "also_ignored"
      options = []

      assert {:error, _} = TokenHandler.on_verify(
        new_claims_without_aud,
        token,
        options
      )
    end

    test "given a revoked token/claim, and no option to store, it returns an error" do
      claims = claims()
      token = "also_ignored"
      options = []

      {:ok, _} = TokenHandler.on_revoke(
        claims,
        token,
        []
      )

      assert {:error, _} = TokenHandler.on_verify(
        claims,
        token,
        options
      )
    end

    test "given a revoked token/claim, and an attempt to store, it returns an error" do
      claims = claims()
      token = "also_ignored"
      options = [store_token: true]

      {:ok, _} = TokenHandler.on_revoke(
        claims,
        token,
        []
      )

      assert {:error, _} = TokenHandler.on_verify(
        claims,
        token,
        options
      )

      assert {:error, _} = TokenHandler.on_verify(
        claims,
        token,
        []
      )
    end

    test "given a revoked token/claim, and the token somehow getting back in the database, it does not return an error" do
      resource = :ignored
      claims = claims()
      token = "also_ignored"
      options = []

      {:ok, _} = TokenHandler.on_revoke(
        claims,
        token,
        []
      )

      {:ok, _} = TokenHandler.after_encode_and_sign(
        resource,
        claims,
        token,
        []
      )

      assert {:ok, _} = TokenHandler.on_verify(
        claims,
        token,
        options
      )
    end

    test "given a revoked token/claim, and option to store, it returns an error" do
      claims = claims()
      token = "also_ignored"
      options = [store_token: true]

      {:ok, _} = TokenHandler.on_revoke(
        claims,
        token,
        []
      )

      assert {:error, _} = TokenHandler.on_verify(
        claims,
        token,
        options
      )
    end
  end

  describe "on_revoke/3" do
    test "given a complete token, it removes it from the database and puts a revoked marker in place" do
      claims = claims()
      token = "also_ignored"
      options = []

      assert {:ok, ^claims} = TokenHandler.on_revoke(
        claims,
        token,
        options
      )

      claims_primary_key = TokenHandler.to_storable_claims(claims)
      revoked_primary_key = TokenHandler.to_revoked_claims(claims)

      assert nil == Guardian.DB.Token.find_by_claims(claims_primary_key)
      assert nil != Guardian.DB.Token.find_by_claims(revoked_primary_key)
    end

    test "given an incomplete token, it returns an error tuple" do
      claims_without_aud = claims()
      |> Map.delete("aud")
      token = "also_ignored"
      options = []

      assert {:error, _} = TokenHandler.on_revoke(
        claims_without_aud,
        token,
        options
      )
    end
  end

  defp claims(overrides \\ %{}) do
    demo_issuer = "https://smartcolumbusos-demo.auth0.com/"
    demo_client_id = "demo_client_id"
    darsh_subject = "auth0|subject-id"

    %{
      "iss"=> demo_issuer,
      "sub"=> darsh_subject,
      "aud"=> ["the", "important", "part"],
      "iat"=> 1_591_298_657,
      "exp"=> 1_591_385_057,
      "azp"=> demo_client_id,
      "scope"=> "openid profile email"
    }
    |> Map.merge(overrides)
  end
end
