defmodule Auth.Test.TokenHandlerExample do
  @moduledoc """
  An example for using the TokenHandler helper
  """

  use Auth.Guardian.TokenHandler, otp_app: :auth
end

defmodule Auth.Guardian.TokenHandlerTest do
  use ExUnit.Case, async: true
  Code.require_file("../../../test_helper.exs", __DIR__)
  import Mox
  use Testing.DataCase,
    repo_module: Auth.Repo

  alias Auth.Test.TokenHandlerExample

  describe "on_verify/3" do
    test "given an unrevoked token, it succeeds" do
      new_claims = claims()
      token = "also_ignored"
      options = []

      assert {:ok, ^new_claims} =
               TokenHandlerExample.on_verify(
                 new_claims,
                 token,
                 options
               )
    end

    test "given an incomplete token, it passes it through" do
      new_claims_without_aud =
        claims()
        |> Map.delete("aud")

      token = "also_ignored"
      options = []

      assert {:ok, _} =
               TokenHandlerExample.on_verify(
                 new_claims_without_aud,
                 token,
                 options
               )
    end

    test "given a revoked token/claim, it returns an error" do
      claims = claims()
      token = "also_ignored"
      options = []

      {:ok, _} =
        TokenHandlerExample.on_revoke(
          claims,
          token,
          []
        )

      assert {:error, _} =
               TokenHandlerExample.on_verify(
                 claims,
                 token,
                 options
               )
    end
  end

  describe "on_revoke/3" do
    test "given a complete token, it puts a revoked marker in place" do
      claims = claims()
      token = "also_ignored"
      options = []

      assert {:ok, ^claims} =
               TokenHandlerExample.on_revoke(
                 claims,
                 token,
                 options
               )

      revoked_primary_key = TokenHandlerExample.to_revoked_claims(claims)

      assert nil != Guardian.DB.Token.find_by_claims(revoked_primary_key)
    end

    test "given an incomplete token, it returns an error tuple" do
      claims_without_aud =
        claims()
        |> Map.delete("aud")

      token = "also_ignored"
      options = []

      assert {:error, _} =
               TokenHandlerExample.on_revoke(
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
      "iss" => demo_issuer,
      "sub" => darsh_subject,
      "aud" => ["the", "important", "part"],
      "iat" => 1_591_298_657,
      "exp" => 1_591_385_057,
      "azp" => demo_client_id,
      "scope" => "openid profile email"
    }
    |> Map.merge(overrides)
  end
end