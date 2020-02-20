defmodule Reaper.Event.Handlers.Helper do
  @moduledoc """
  Holds common helper functions for dataset handlers
  """
  require Logger
  use Retry

  def deactivate_quantum_job(dataset_id) do
    dataset_id
    |> String.to_atom()
    |> Reaper.Scheduler.deactivate_job()
  end

  def retry_stopping_dataset(registry, dataset_id) do
    retry with: constant_backoff(100) |> Stream.take(10), atoms: [:not_running] do
      case registry.lookup(dataset_id) do
        nil ->
          :not_running

        pid ->
          Reaper.Horde.Supervisor.terminate_child(pid)
          Logger.info("Stopped #{registry} with pid: #{inspect(pid)} for dataset #{dataset_id}")
      end
    after
      _result ->
        :ok
    else
      :not_running ->
        :ok

      error ->
        Logger.error(inspect(error))
        {:error, error}
    end
  end
end
