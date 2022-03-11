defmodule Andi.Services.IngestionDelete do
  @moduledoc """
  Service for deleting ingestions
  """
  import SmartCity.Event, only: [ingestion_delete: 0]
  alias Andi.Services.IngestionStore

  @instance_name Andi.instance_name()

  @doc """
  Delete an ingestion
  """
  @spec delete(term()) :: {:ok, SmartCity.Ingestion.t()} | {:error, any()} | {:not_found, any()}
  def delete(ingestion_id) do
    with {:ok, ingestion} when not is_nil(ingestion) <- IngestionStore.get(ingestion_id),
         :ok <- Brook.Event.send(@instance_name, ingestion_delete(), :andi, ingestion) do
      {:ok, ingestion}
    else
      {:ok, nil} ->
        {:not_found, ingestion_id}

      error ->
        error
    end
  end
end
