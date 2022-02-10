defmodule Reaper.Event.Handlers.Helper.StopIngestion do
  @moduledoc false

  require Logger
  use Retry

  def stop_horde_and_cache(ingestion_id) do
    with :ok <- retry_stopping_ingestion(Reaper.Horde.Registry, ingestion_id),
         :ok <- retry_stopping_ingestion(Reaper.Cache.Registry, ingestion_id) do
      :ok
    else
      error -> {:error, error}
    end
  end

  defp retry_stopping_ingestion(registry, ingestion_id) do
    retry with: constant_backoff(100) |> Stream.take(10), atoms: [:not_running] do
      case registry.lookup(ingestion_id) do
        nil ->
          :not_running

        pid ->
          Reaper.Horde.Supervisor.terminate_child(pid)
          Logger.info("Stopped #{registry} with pid: #{inspect(pid)} for ingestion #{ingestion_id}")
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

  def deactivate_quantum_job(ingestion_id) do
    ingestion_id
    |> String.to_atom()
    |> Reaper.Scheduler.deactivate_job()
  end

  def delete_quantum_job(ingestion_id) do
    ingestion_id
    |> String.to_atom()
    |> Reaper.Scheduler.delete_job()
  end
end
