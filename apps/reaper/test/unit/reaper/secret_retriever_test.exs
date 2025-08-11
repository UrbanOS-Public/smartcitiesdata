defmodule Reaper.SecretRetrieverTest do
  use ExUnit.Case
  import ExUnit.CaptureLog
  alias Reaper.SecretRetriever

  describe "retrieve/1" do
    setup do
      credentials = %{"username" => "admin", "password" => "1234"}

      %{
        ingestion_id: 1,
        role: "reaper-role",
        jwt: "asjdhfsa",
        credentials: credentials,
        vault: %Vault{engine: :secrets_engine, host: "http://vault:8200", auth: :auth_backend}
      }
    end

    test "retrieves credentials for given ingestion_id", values do
      :meck.new(File, [:unstick])
      :meck.expect(File, :read, fn "/var/run/secrets/kubernetes.io/serviceaccount/token" -> {:ok, values.jwt} end)
      
      :meck.new(Vault, [:non_strict])
      :meck.expect(Vault, :new, fn _ -> values.vault end)
      :meck.expect(Vault, :auth, fn _, %{role: "reaper-role", jwt: _} -> {:ok, values.vault} end)
      expected_path = "secrets/smart_city/ingestion/#{values.ingestion_id}"
      :meck.expect(Vault, :read, fn _, ^expected_path -> {:ok, values.credentials} end)

      assert SecretRetriever.retrieve_ingestion_credentials(values.ingestion_id) == {:ok, values.credentials}
      
      :meck.unload(File)
      :meck.unload(Vault)
    end

    test "returns error when kubernetes token file is not found", values do
      :meck.new(File, [:unstick])
      :meck.expect(File, :read, fn "/var/run/secrets/kubernetes.io/serviceaccount/token" -> {:error, :enoent} end)

      assert capture_log(fn ->
               assert SecretRetriever.retrieve_ingestion_credentials(values.ingestion_id) ==
                        {:error, :retrieve_credential_failed}
             end) =~ "Secret token file not found"
      
      :meck.unload(File)
    end

    test "returns error when vault service is unavailable", values do
      :meck.new(File, [:unstick])
      :meck.expect(File, :read, fn "/var/run/secrets/kubernetes.io/serviceaccount/token" -> {:ok, values.jwt} end)
      
      :meck.new(Vault, [:non_strict])
      :meck.expect(Vault, :new, fn _ -> values.vault end)
      :meck.expect(Vault, :auth, fn _, %{role: "reaper-role", jwt: _} -> {:error, ["Something bad happened"]} end)

      assert capture_log(fn ->
               assert SecretRetriever.retrieve_ingestion_credentials(values.ingestion_id) ==
                        {:error, :retrieve_credential_failed}
             end) =~ "Something bad happened"
      
      :meck.unload(File)
      :meck.unload(Vault)
    end
  end
end
