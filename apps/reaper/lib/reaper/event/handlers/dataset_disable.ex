defmodule Reaper.Event.Handlers.DatasetDisable do
  @moduledoc false
  require Logger
  use Retry

  def handle(%SmartCity.Dataset{id: dataset_id}) do
    with :ok <- deactivate_quantum_job(dataset_id),
         :ok <- retry_stopping_dataset(Reaper.Horde.Registry, dataset_id),
         :ok <- retry_stopping_dataset(Reaper.Cache.Registry, dataset_id) do
      :ok
    else
      error -> error
    end
  end

  defp deactivate_quantum_job(dataset_id) do
    dataset_id
    |> String.to_atom()
    |> Reaper.Scheduler.deactivate_job()
  end

  defp retry_stopping_dataset(registry, dataset_id) do
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
