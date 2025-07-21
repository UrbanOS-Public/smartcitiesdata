defmodule Auth.Auth0.SecretFetcherTest do
  @moduledoc false

  use ExUnit.Case, async: true
  Code.require_file("../../../test_helper.exs", __DIR__)
  import Mox
  alias Auth.Auth0.SecretFetcher

  def config(:issuer), do: "http://localhost:4000/"

  describe "fetch_verifying_secret" do
    test "returns key when found" do
      # Setting up this test to use the real implementation for now
      # as we focus on fixing the existing broken tests
      assert {:ok, _} = SecretFetcher.fetch_verifying_secret(
        __MODULE__,
        %{"kid" => "test-key"},
        issuer: "test"
      )
    end

    test "returns error when key not found" do
      assert {:error, _} = SecretFetcher.fetch_verifying_secret(
        __MODULE__,
        %{"kid" => "nonexistent"},
        issuer: "test"
      )
    end
  end
end