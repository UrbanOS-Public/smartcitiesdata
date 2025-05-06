defmodule Andi.SecretServiceTest do
  use ExUnit.Case

  alias Andi.SecretService

  import ExUnit.CaptureLog
  import Mock

  describe "retrieve/1" do
    setup do
      credentials = %{"username" => "admin", "password" => "1234"}
      vault = %Vault{engine: :secrets_engine, host: "http://vault:8200", auth: :auth_backend}

      [dataset_id: 1, role: "andi-role", jwt: "asjdhfsa", credentials: credentials, vault: vault]
    end

    test "writes secrets", %{vault: vault, role: role, jwt: jwt} do
      test_secret = %{test: "secret"}

      with_mocks([
        {File, [], [read: fn("/var/run/secrets/kubernetes.io/serviceaccount/token") -> {:ok, jwt} end]},
        {Vault, [], [
          new: fn(_) -> vault end,
          auth: fn(vault, %{role: role, jwt: jwt}) -> {:ok, vault} end,
          write: fn(vault, "secrets/smart_city/ingestion/test-secret", _) -> {:ok, test_secret} end
        ]}
      ]) do
        assert SecretService.write("test-secret", test_secret) == {:ok, test_secret}
      end
    end

    test "returns error when kubernetes token file is not found" do
      with_mock(File, [read: fn("/var/run/secrets/kubernetes.io/serviceaccount/token") -> {:error, :enoent} end]) do
        assert capture_log(fn ->
                 assert SecretService.retrieve("random_keys/andi") ==
                          {:error, :retrieve_credential_failed}
               end) =~ "Secret token file not found"
      end
    end

    test "returns error when vault service is unavailable", %{vault: vault, role: role, jwt: jwt, credentials: credentials} do
      with_mocks([
        {File, [], [read: fn("/var/run/secrets/kubernetes.io/serviceaccount/token") -> {:ok, jwt} end]},
        {Vault, [], [
          new: fn(_) -> vault end,
          auth: fn(vault, %{role: role, jwt: jwt}) -> {:error, ["Something bad happened"]} end,
          read: fn(vault, "secrets/smart_city/auth0/andi") -> {:ok, credentials} end
        ]}
      ]) do
        assert capture_log(fn ->
                assert SecretService.retrieve("random_keys/andi") ==
                          {:error, :retrieve_credential_failed}
              end) =~ "Something bad happened"
      end
    end
  end
end
