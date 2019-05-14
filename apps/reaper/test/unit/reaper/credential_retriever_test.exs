defmodule Reaper.CredentialRetrieverTest do
  use ExUnit.Case
  use Placebo
  alias Reaper.CredentialRetriever
  import ExUnit.CaptureLog

  describe "retrieve/1" do
    setup do
      credentials = ~s({"username": "admin", "password": "1234"})

      %{
        dataset_id: 1,
        role: "app-role",
        jwt: "asjdhfsa",
        credentials: credentials,
        credentials_decoded: Jason.decode!(credentials),
        vault: %Vault{engine: :secrets_engine, host: "http://vault:8200", auth: :auth_backend}
      }
    end

    test "retrieves credentials for given dataset_id", values do
      allow File.read("/var/run/secrets/kubernetes.io/serviceaccount/token"), return: {:ok, values.jwt}
      allow Vault.new(any()), return: values.vault
      allow Vault.auth(values.vault, %{role: values.role, jwt: values.jwt}), return: {:ok, values.vault}

      allow Vault.read(values.vault, "secrets/smart_city/ingestion/#{values.dataset_id}"),
        return: {:ok, values.credentials}

      assert CredentialRetriever.retrieve(values.dataset_id) == {:ok, values.credentials_decoded}
    end

    test "returns error when kubernetes token file is not found", values do
      allow File.read("/var/run/secrets/kubernetes.io/serviceaccount/token"), return: {:error, :enoent}

      assert capture_log(fn ->
               assert CredentialRetriever.retrieve(values.dataset_id) == {:error, :retrieve_credential_failed}
             end) =~ ~s(Secret token file not found)
    end

    test "returns error when vault service is unavailable", values do
      allow File.read("/var/run/secrets/kubernetes.io/serviceaccount/token"), return: {:ok, values.jwt}
      allow Vault.new(any()), return: values.vault

      allow Vault.auth(values.vault, %{role: values.role, jwt: values.jwt}),
        return: {:error, ["Http adapter error", ":socket_closed_remotely"]}

      assert capture_log(fn ->
               assert CredentialRetriever.retrieve(values.dataset_id) == {:error, :retrieve_credential_failed}
             end) =~ ~s(Http adapter error:socket_closed_remotely)
    end

    test "returns error when app role is invalid", values do
      allow File.read("/var/run/secrets/kubernetes.io/serviceaccount/token"), return: {:ok, values.jwt}
      allow Vault.new(any()), return: values.vault

      allow Vault.auth(values.vault, %{role: values.role, jwt: values.jwt}),
        return: {:error, ["invalid role name \"app-roe\""]}

      assert capture_log(fn ->
               assert CredentialRetriever.retrieve(values.dataset_id) == {:error, :retrieve_credential_failed}
             end) =~ ~s(invalid role name "app-roe")
    end
  end
end
