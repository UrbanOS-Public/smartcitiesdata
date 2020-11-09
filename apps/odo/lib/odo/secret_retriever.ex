defmodule Odo.SecretRetriever do
  @moduledoc """
  Retrieves credentials for use in accessing restricted datasets.
  """
  use Properties, otp_app: :odo

  require Logger

  @root_path "secrets/smart_city/"

  getter(:secrets_endpoint, generic: true)

  def retrieve_objectstore_keys() do
    retrieve("aws_keys/odo")
  end

  defp retrieve(path) do
    vault_path = "#{@root_path}#{path}"

    with {:ok, jwt} <- get_kubernetes_token(),
         {:ok, vault} <- instantiate_vault_conn(jwt),
         {:ok, credentials} <- Vault.read(vault, vault_path) do
      {:ok, credentials}
    else
      {:error, reason} ->
        Logger.error("Unable to retrieve dataset credential; #{reason}")
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
    |> Vault.auth(%{role: "odo-role", jwt: token})
  end

  defp set_login_ttl(time, interval), do: NaiveDateTime.utc_now() |> NaiveDateTime.add(time, interval)
end
