defmodule Reaper.SecretRetrieverBehaviour do
  @callback retrieve_ingestion_credentials(String.t()) :: {:ok, map()} | {:error, any()}
end