defmodule Andi.Services.DatasetDelete do
  @moduledoc """
  Service for deleting datasets
  """
  import SmartCity.Event, only: [dataset_delete: 0]
  alias Andi.Services.DatasetStore

  @instance_name Andi.instance_name()

  @doc """
  Delete a dataset
  """
  @spec delete(term()) :: {:ok, SmartCity.Dataset.t()} | {:error, any()} | {:not_found, any()}
  def delete(dataset_id) do
    with {:ok, dataset} when not is_nil(dataset) <- DatasetStore.get(dataset_id),
         _ <- Andi.Schemas.AuditEvents.log_audit_event(:api, dataset_delete(), dataset),
         :ok <- Brook.Event.send(@instance_name, dataset_delete(), :andi, dataset) do
      {:ok, dataset}
    else
      {:ok, nil} ->
        {:not_found, dataset_id}

      error ->
        error
    end
  end
end
