defmodule Reaper.VaultTokenDebugger do
  @moduledoc """
  Provides debugging functionality to manually trigger and inspect HCP Vault token generation.
  This module is designed for debugging purposes and can be executed from an Elixir remote console.
  """

  require Logger

  @doc """
  Manually triggers the Vault token fetching process and prints the token details.
  This function replicates the exact token generation process used during runtime.

  ## Examples

      iex> Reaper.VaultTokenDebugger.debug_vault_token()
      :ok

  """
  def debug_vault_token do
    IO.puts("=== HCP Vault Token Debug ===")
    IO.puts("Starting Vault token generation process...")

    with {:ok, jwt_token} <- get_kubernetes_token(),
         IO.puts("✓ Successfully retrieved Kubernetes JWT token"),
         IO.puts("JWT token (first 50 chars): #{String.slice(jwt_token, 0, 50)}..."),
         {:ok, vault_conn} <- instantiate_vault_connection(jwt_token),
         IO.puts("✓ Successfully instantiated Vault connection"),
         IO.puts("Vault host: #{vault_conn.host}"),
         IO.puts("Vault engine: #{inspect(vault_conn.engine)}"),
         IO.puts("Vault auth: #{inspect(vault_conn.auth)}"),
         IO.puts("Token expires at: #{vault_conn.token_expires_at}"),
         :ok <- validate_vault_connection(vault_conn) do
      IO.puts("✓ Vault connection validated successfully")
      IO.puts("=== Token Generation Complete ===")
      IO.puts("Vault connection is ready for use.")
      :ok
    else
      {:error, reason} ->
        IO.puts("✗ Error during token generation: #{inspect(reason)}")
        Logger.error("Vault token debug failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Tests Vault token retrieval for a specific ingestion ID.

  ## Examples

      iex> Reaper.VaultTokenDebugger.test_ingestion_credentials("test-ingestion-id")
      :ok

  """
  def test_ingestion_credentials(ingestion_id) do
    IO.puts("=== Testing Ingestion Credentials ===")
    IO.puts("Ingestion ID: #{ingestion_id}")

    case Reaper.SecretRetriever.retrieve_ingestion_credentials(ingestion_id) do
      {:ok, credentials} ->
        IO.puts("✓ Successfully retrieved credentials")
        IO.puts("Credentials: #{inspect(credentials)}")
        :ok

      {:error, reason} ->
        IO.puts("✗ Failed to retrieve credentials: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Prints detailed Vault configuration information.
  """
  def print_vault_config do
    IO.puts("=== Vault Configuration ===")

    secrets_endpoint = Application.get_env(:reaper, :secrets_endpoint)
    IO.puts("Secrets Endpoint: #{secrets_endpoint}")

    vault_role = "reaper-role"
    IO.puts("Vault Role: #{vault_role}")

    token_file = "/var/run/secrets/kubernetes.io/serviceaccount/token"
    IO.puts("Kubernetes Token File: #{token_file}")

    case File.exists?(token_file) do
      true -> IO.puts("✓ Token file exists")
      false -> IO.puts("✗ Token file not found")
    end

    :ok
  end

  # Private functions - replicate the exact logic from SecretRetriever

  defp get_kubernetes_token do
    token_file = "/var/run/secrets/kubernetes.io/serviceaccount/token"

    case File.read(token_file) do
      {:ok, token} ->
        IO.puts("Token file read successfully")
        {:ok, token}

      {:error, :enoent} ->
        IO.puts("Token file not found at #{token_file}")
        {:error, "Secret token file not found"}

      {:error, reason} ->
        IO.puts("Error reading token file: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp instantiate_vault_connection(token) do
    # Reads the flat :secrets_endpoint key (config :reaper, secrets_endpoint: ...,
    # matching Reaper.SecretRetriever's own `getter(:secrets_endpoint, generic: true)`)
    # rather than a Reaper.SecretRetriever-nested key, which this app never configures.
    secrets_endpoint = Application.get_env(:reaper, :secrets_endpoint)

    if is_nil(secrets_endpoint) or secrets_endpoint == "" do
      IO.puts("✗ SECRETS_ENDPOINT is not set or empty")
      {:error, "SECRETS_ENDPOINT environment variable is not set or empty"}
    else
      vault =
        Vault.new(
          engine: Vault.Engine.KVV1,
          auth: Vault.Auth.Kubernetes,
          host: secrets_endpoint,
          token_expires_at: set_login_ttl(20, :second)
        )

      case Vault.auth(vault, %{role: "reaper-role", jwt: token}) do
        {:ok, authenticated_vault} ->
          {:ok, authenticated_vault}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp validate_vault_connection(vault_conn) do
    # Try to read a simple path to validate the connection
    test_path = "secrets/smart_city/"

    case Vault.read(vault_conn, test_path) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        IO.puts("Vault validation failed: #{inspect(reason)}")
        {:error, :vault_validation_failed}
    end
  end

  defp set_login_ttl(time, interval) do
    NaiveDateTime.utc_now() |> NaiveDateTime.add(time, interval)
  end
end
