defmodule Andi.Services.DatasetDisableService do
  @moduledoc """
  Service for disabling datasets
  """
  import SmartCity.Event, only: [dataset_disable: 0]

  @doc """
  Disable a dataset
  """
  @spec disable(term()) :: {:ok, SmartCity.Dataset.t()} | {:error, any()}
  def disable(dataset_id) do
    with {:ok, dataset} <- Brook.get(:dataset, dataset_id),
         :ok <- Brook.Event.send(dataset_disable(), :andi, dataset) do
      {:ok, dataset}
    else
      error -> error
    end
  end
end
