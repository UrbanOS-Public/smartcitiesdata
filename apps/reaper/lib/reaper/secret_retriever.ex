defmodule Reaper.SecretRetriever do
  @moduledoc """
  Retrieves credentials for use in accessing restricted datasets.
  """
  require Logger

  @root_path "secrets/smart_city/"

  def retrieve_dataset_credentials(dataset_id) do
    retrieve("ingestion/#{dataset_id}")
  end

  def retrieve_aws_keys() do
    retrieve("aws_keys/reaper")
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
      host: get_secrets_endpoint(),
      token_expires_at: set_login_ttl(20, :second)
    )
    |> Vault.auth(%{role: "reaper-role", jwt: token})
  end

  defp set_login_ttl(time, interval), do: NaiveDateTime.utc_now() |> NaiveDateTime.add(time, interval)

  defp get_secrets_endpoint(), do: Application.get_env(:reaper, :secrets_endpoint)
end
