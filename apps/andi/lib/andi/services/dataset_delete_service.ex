defmodule Andi.Services.DatasetDelete do
  @moduledoc """
  Service for deleting datasets
  """
  import Andi
  import SmartCity.Event, only: [dataset_delete: 0]
  alias Andi.DatasetStore

  @doc """
  Delete a dataset
  """
  @spec delete(term()) :: {:ok, SmartCity.Dataset.t()} | {:error, any()} | {:not_found, any()}
  def delete(dataset_id) do
    with {:ok, dataset} when not is_nil(dataset) <- DatasetStore.get_dataset(dataset_id),
         :ok <- Brook.Event.send(instance_name(), dataset_delete(), :andi, dataset) do
      {:ok, dataset}
    else
      {:ok, nil} ->
        {:not_found, dataset_id}

      error ->
        error
    end
  end
end
