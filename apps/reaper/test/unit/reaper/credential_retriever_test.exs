defmodule Reaper.CredentialRetrieverTest do
  use ExUnit.Case
  use Placebo
  alias Reaper.CredentialRetriever

  describe "retrieve/1" do
    test "retrieves credentials for given dataset_id" do
      dataset_id = 1
      role = "demo-role"
      jwt = "asjdhfsa"
      credentials = ~s({"username": "admin", "password": "1234"})
      credentials_decoded = Jason.decode!(credentials)
      vault = [engine: :engine, host: :host]

      allow File.read("/var/run/secrets/kubernetes.io/serviceaccount/token"), return: {:ok, jwt}
      allow Vault.new(any()), return: vault
      allow Vault.auth(vault, %{role: role, jwt: jwt}), return: {:ok, vault}
      allow Vault.read(vault, "secrets/smartcity/ingestion/#{dataset_id}"), return: {:ok, credentials}

      assert CredentialRetriever.retrieve(dataset_id) == {:ok, credentials_decoded}
    end

    test "returns error when kubernetes token file is not found" do
      dataset_id = 1

      allow File.read("/var/run/secrets/kubernetes.io/serviceaccount/token"), return: {:error, :enoent}

      assert CredentialRetriever.retrieve(dataset_id) == {:error, :local_secret_not_found}
    end

    test "returns error when unable to authorize" do
      dataset_id = 1
      role = "demo-role"
      jwt = "asjdhfsa"
      vault = [engine: :engine, host: :host]

      allow File.read("/var/run/secrets/kubernetes.io/serviceaccount/token"), return: {:ok, jwt}
      allow Vault.new(any()), return: vault

      allow Vault.auth(vault, %{role: role, jwt: jwt}),
        return: {:error, ["Http adapter error", ":socket_closed_remotely"]}

      assert CredentialRetriever.retrieve(dataset_id) == {:error, :failed_to_authorize}
    end
  end
end
