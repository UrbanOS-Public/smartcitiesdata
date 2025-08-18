defmodule Andi.SecretServiceTest do
  use ExUnit.Case

  alias Andi.SecretService

  import ExUnit.CaptureLog
  
  @moduletag timeout: 5000

  describe "retrieve/1" do
    setup do
      # Set up :meck for File and Vault modules
      modules_to_mock = [File, Vault]
      
      # Clean up any existing mocks first
      Enum.each(modules_to_mock, fn module ->
        try do
          :meck.unload(module)
        catch
          _, _ -> :ok
        end
      end)
      
      # Set up fresh mocks
      Enum.each(modules_to_mock, fn module ->
        try do
          :meck.new(module, [:passthrough])
        catch
          :error, {:already_started, _} -> :ok
        end
      end)
      
      on_exit(fn ->
        Enum.each(modules_to_mock, fn module ->
          try do
            :meck.unload(module)
          catch
            _, _ -> :ok
          end
        end)
      end)
      
      credentials = %{"username" => "admin", "password" => "1234"}
      vault = %Vault{engine: :secrets_engine, host: "http://vault:8200", auth: :auth_backend}

      [dataset_id: 1, role: "andi-role", jwt: "asjdhfsa", credentials: credentials, vault: vault]
    end

    test "writes secrets", %{vault: vault, role: role, jwt: jwt} do
      test_secret = %{test: "secret"}
      
      # Set up expectations for this test
      :meck.expect(File, :read, fn "/var/run/secrets/kubernetes.io/serviceaccount/token" -> {:ok, jwt} end)
      :meck.expect(Vault, :new, fn _ -> vault end)
      :meck.expect(Vault, :auth, fn ^vault, %{role: ^role, jwt: ^jwt} -> {:ok, vault} end)
      :meck.expect(Vault, :write, fn ^vault, "secrets/smart_city/ingestion/test-secret", _ -> {:ok, test_secret} end)
      
      assert SecretService.write("test-secret", test_secret) == {:ok, test_secret}
      
      # Verify calls were made
      assert :meck.num_calls(File, :read, 1) == 1
      assert :meck.num_calls(Vault, :new, 1) == 1
      assert :meck.num_calls(Vault, :auth, 2) == 1
      assert :meck.num_calls(Vault, :write, 3) == 1
    end

    test "returns error when kubernetes token file is not found" do
      # Set up expectations for this test
      :meck.expect(File, :read, fn "/var/run/secrets/kubernetes.io/serviceaccount/token" -> {:error, :enoent} end)
      
      assert capture_log(fn ->
               assert SecretService.retrieve("random_keys/andi") ==
                        {:error, :retrieve_credential_failed}
             end) =~ "Secret token file not found"
      
      # Verify calls were made
      assert :meck.num_calls(File, :read, 1) == 1
    end

    test "returns error when vault service is unavailable", %{vault: vault, role: role, jwt: jwt, credentials: _credentials} do
      # Set up expectations for this test
      :meck.expect(File, :read, fn "/var/run/secrets/kubernetes.io/serviceaccount/token" -> {:ok, jwt} end)
      :meck.expect(Vault, :new, fn _ -> vault end)
      :meck.expect(Vault, :auth, fn ^vault, %{role: ^role, jwt: ^jwt} -> {:error, ["Something bad happened"]} end)
      
      assert capture_log(fn ->
               assert SecretService.retrieve("random_keys/andi") ==
                        {:error, :retrieve_credential_failed}
             end) =~ "Something bad happened"
      
      # Verify calls were made
      assert :meck.num_calls(File, :read, 1) == 1
      assert :meck.num_calls(Vault, :new, 1) == 1
      assert :meck.num_calls(Vault, :auth, 2) == 1
    end
  end
end
