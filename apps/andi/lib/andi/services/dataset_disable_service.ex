# TODO - reaper no longer listens for dataset_disable() events. This is dead code to remove.
defmodule Andi.Services.DatasetDisable do
  @moduledoc """
  Service for disabling datasets
  """
  import SmartCity.Event, only: [dataset_disable: 0]
  alias Andi.Services.DatasetStore

  @instance_name Andi.instance_name()

  @doc """
  Disable a dataset
  """
  @spec disable(term()) :: {:ok, SmartCity.Dataset.t()} | {:error, any()} | {:not_found, any()}
  def disable(dataset_id) do
    with {:ok, dataset} when not is_nil(dataset) <- DatasetStore.get(dataset_id),
         :ok <- Brook.Event.send(@instance_name, dataset_disable(), :andi, dataset) do
      {:ok, dataset}
    else
      {:ok, nil} ->
        {:not_found, dataset_id}

      error ->
        error
    end
  end
end
