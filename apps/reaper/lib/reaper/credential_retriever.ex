defmodule Reaper.CredentialRetriever do
  @moduledoc """
  Retrieves credentials for use in accessing restricted datasets.
  """

  def retrieve(dataset_id) do
    vault =
      Vault.new(
        engine: Vault.Engine.KVV1,
        auth: Vault.Auth.Kubernetes,
        host: "http://vault.vault:8200"
      )

    with {:ok, jwt} <- File.read("/var/run/secrets/kubernetes.io/serviceaccount/token"),
         {:ok, token, _ttl} <- Vault.Auth.Kubernetes.login(vault, %{role: "demo-role", jwt: jwt}),
         {:ok, credentials} <- Vault.read(vault, "secrets/smartcity/ingestion/#{dataset_id}"),
         {:ok, decoded_credentials} <- Jason.decode(credentials) do
      decoded_credentials
    end
  end
end
