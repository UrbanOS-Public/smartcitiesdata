defmodule Reaper.CredentialRetrieverTest do
  use ExUnit.Case
  use Placebo
  alias Reaper.CredentialRetriever

  describe "retrieve/1" do
    test "retrieves credentials for given dataset_id" do
      dataset_id = 1
      role = "demo-role"
      jwt = "asjdhfsa"
      token = "token"
      credentials = ~s({"username": "admin", "password": "1234"})
      credentials_decoded = Jason.decode!(credentials)
      vault = [engine: :engine, host: :host]

      allow File.read("/var/run/secrets/kubernetes.io/serviceaccount/token"), return: {:ok, jwt}
      allow Vault.new(any()), return: vault
      allow Vault.Auth.Kubernetes.login(vault, %{role: role, jwt: jwt}), return: {:ok, token, 99_999}
      allow Vault.read(vault, "secrets/smartcity/ingestion/#{dataset_id}"), return: {:ok, credentials}

      assert CredentialRetriever.retrieve(dataset_id) == credentials_decoded
    end
  end
end
