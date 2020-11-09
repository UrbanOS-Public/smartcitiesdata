defmodule Andi.SecretRetriever do
  @moduledoc """
  Retrieves credentials for auth0 configuration
  """
  use Properties, otp_app: :andi

  require Logger

  @root_path "secrets/smart_city/"

  getter(:secrets_endpoint, generic: true)

  def retrieve_auth0_credentials(), do: retrieve("auth0/andi")

  def retrieve(path) do
    vault_path = "#{@root_path}#{path}"

    with {:ok, jwt} <- get_kubernetes_token(),
         {:ok, vault} <- instantiate_vault_conn(jwt),
         {:ok, credentials} <- Vault.read(vault, vault_path) do
      {:ok, credentials}
    else
      {:error, reason} ->
        Logger.error("Unable to retrieve auth credential: #{reason}")
        {:error, :retrieve_credential_failed}
    end
  end

  defp get_kubernetes_token() do
    case File.read("/var/run/secrets/kubernetes.io/serviceaccount/token") do
      {:error, :enoent} -> {:error, "Secret token file not found"}
      token -> token
    end
  end

  defp instantiate_vault_conn(token) do
    Vault.new(
      engine: Vault.Engine.KVV1,
      auth: Vault.Auth.Kubernetes,
      host: secrets_endpoint(),
      token_expires_at: set_login_ttl(20, :second)
    )
    |> Vault.auth(%{role: "andi-role", jwt: token})
  end

  defp set_login_ttl(time, interval), do: NaiveDateTime.utc_now() |> NaiveDateTime.add(time, interval)
end
