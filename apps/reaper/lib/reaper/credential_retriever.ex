defmodule Reaper.CredentialRetriever do
  @moduledoc """
  Retrieves credentials for use in accessing restricted datasets.
  """
  require Logger

  def retrieve(dataset_id) do
    with {:ok, jwt} <- get_kubernetes_token(),
         {:ok, vault} <- instantiate_vault_conn(jwt),
         {:ok, credentials} <- Vault.read(vault, "secrets/smartcity/ingestion/#{dataset_id}"),
         {:ok, decoded_credentials} <- Jason.decode(credentials) do
      {:ok, decoded_credentials}
    else
      {:error, :enoent} ->
        Logger.error("Dataset credentials not found")
        {:error, :local_secret_not_found}

      {:error, error} ->
        Logger.error("Unable to connect to vault: #{error}")
        {:error, :failed_to_authorize}
    end

    # {:error, ["Http adapter error", ":socket_closed_remotely"]} - host not found
    # {:error, ["invalid role name \"demo-ro\""]}
    # {:error, ["Missing credentials - role and jwt are required.", %{jwt: nil, role: "demo-role"}]}
  end

  defp get_kubernetes_token() do
    case File.read("/var/run/secrets/kubernetes.io/serviceaccount/token") do
      {:error, :enoent} ->
        Logger.error("Secret token file not found")
        {:error, :local_secret_not_found}

      token ->
        token
    end
  end

  defp instantiate_vault_conn(token) do
    try do
      Vault.new(
        engine: Vault.Engine.KVV1,
        auth: Vault.Auth.Kubernetes,
        host: "http://vault.vault:8200",
        token_expires_at: set_login_ttl(20, :second)
      )
      |> Vault.auth(%{role: "demo-role", jwt: token})
    rescue
      UndefinedFunctionError ->
        Logger.error("Incorrect auth engine configuration")
        {:error, :incorrect_auth_engine}

      MatchError ->
        Logger.error("Incorrect secrets host or token configuration")
        {:error, :incorrect_secrets_host}
    end
  end

  defp set_login_ttl(time, interval), do: NaiveDateTime.utc_now() |> NaiveDateTime.add(time, interval)
end
