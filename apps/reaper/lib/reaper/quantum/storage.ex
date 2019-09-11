defmodule Reaper.Quantum.Storage do
  @moduledoc """
  Implementation of Quantum.Storage.Adapter
  """
  @behaviour Quantum.Storage.Adapter

  @conn :reaper_quantum_storage_redix

  def child_spec(_args) do
    config = Application.get_env(:reaper, Reaper.Quantum.Storage)
    Supervisor.child_spec({Redix, [host: Keyword.fetch!(config, :redis_host), name: @conn]}, id: @conn)
  end

  @impl Quantum.Storage.Adapter
  def last_execution_date(scheduler) do
    case get(date_key(scheduler)) do
      nil -> :unknown
      date -> deserialize(date)
    end
  end

  @impl Quantum.Storage.Adapter
  def purge(scheduler) do
    base_key(scheduler, "*")
    |> keys()
    |> delete()

    :ok
  end

  @impl Quantum.Storage.Adapter
  def update_job_state(scheduler, job_name, state) do
    job = get(job_key(scheduler, job_name)) |> deserialize()
    updated_job = %{job | state: state}
    set(job_key(scheduler, job_name), serialize(updated_job))
  end

  @impl Quantum.Storage.Adapter
  def update_last_execution_date(scheduler, date) do
    set(date_key(scheduler), serialize(date))
    :ok
  end

  @impl Quantum.Storage.Adapter
  def add_job(scheduler, job) do
    set(job_key(scheduler, job.name), serialize(job))
    :ok
  end

  @impl Quantum.Storage.Adapter
  def delete_job(scheduler, job_name) do
    delete(job_key(scheduler, job_name))
    :ok
  end

  @impl Quantum.Storage.Adapter
  def jobs(scheduler) do
    case keys(job_key(scheduler, "*")) do
      [] ->
        :not_applicable

      keys ->
        keys
        |> mget()
        |> Enum.map(&deserialize/1)
    end
  end

  defp job_key(scheduler, job_name) do
    base_key(scheduler, "job:#{job_name}")
  end

  defp date_key(scheduler) do
    base_key(scheduler, "last_execution_date")
  end

  defp base_key(scheduler, suffix) do
    scheduler_name = scheduler |> to_string() |> String.downcase()
    "reaper:quantum:#{scheduler_name}:#{suffix}"
  end

  defp set(key, value) do
    Redix.command!(@conn, ["SET", key, value])
  end

  defp delete([]), do: nil

  defp delete(keys) when is_list(keys) do
    Redix.command!(@conn, ["DEL" | keys])
  end

  defp delete(key) do
    Redix.command!(@conn, ["DEL", key])
  end

  defp keys(key) do
    Redix.command!(@conn, ["KEYS", key])
  end

  defp mget(keys) do
    Redix.command!(@conn, ["MGET" | keys])
  end

  defp get(key) do
    Redix.command!(@conn, ["GET", key])
  end

  defp serialize(job) do
    :erlang.term_to_binary(job)
  end

  defp deserialize(value) do
    :erlang.binary_to_term(value)
  end
end
