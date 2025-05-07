defmodule Reaper.Quantum.Storage do
  @moduledoc """
  Implementation of Quantum.Storage.Adapter
  """
  @behaviour Quantum.Storage.Adapter
  require Retry
  require Logger

  @conn Reaper.Quantum.Storage.Connection.connection()
  @config Application.get_env(:reaper, Reaper.Quantum.Storage, [])
  @retry_delay Keyword.get(@config, :retry_delay, 1_000)
  @max_retries Keyword.get(@config, :max_retries, 60)

  defdelegate child_spec(args), to: Reaper.Quantum.Storage.Connection

  @impl Quantum.Storage.Adapter
  def last_execution_date(scheduler) do
    retry(
      fn ->
        case get(date_key(scheduler)) do
          {:ok, nil} -> {:ok, :unknown}
          {:ok, date} -> {:ok, deserialize(date)}
          error -> error
        end
      end,
      use_return: true
    )
  end

  @impl Quantum.Storage.Adapter
  def purge(scheduler) do
    retry(fn ->
      with {:ok, keys} <- keys(base_key(scheduler, "*")) do
        delete(keys)
      end
    end)
  end

  @impl Quantum.Storage.Adapter
  def update_job_state(scheduler, job_name, state) do
    retry(fn ->
      with {:ok, serialized_job} <- get(job_key(scheduler, job_name)),
           job <- deserialize(serialized_job) do
        set(job_key(scheduler, job_name), serialize(%{job | state: state}))
      end
    end)
  end

  @impl Quantum.Storage.Adapter
  def update_last_execution_date(scheduler, date) do
    retry(fn -> set(date_key(scheduler), serialize(date)) end)
  end

  @impl Quantum.Storage.Adapter
  def add_job(scheduler, job) do
    retry(fn -> set(job_key(scheduler, job.name), serialize(job)) end)
  end

  @impl Quantum.Storage.Adapter
  def delete_job(scheduler, job_name) do
    retry(fn -> delete(job_key(scheduler, job_name)) end)
  end

  @impl Quantum.Storage.Adapter
  def jobs(scheduler) do
    retry(
      fn ->
        with {:ok, keys} when keys != [] <- keys(job_key(scheduler, "*")),
             {:ok, values} <- mget(keys) do
          {:ok, Enum.map(values, &deserialize/1)}
        else
          {:ok, []} -> {:ok, :not_applicable}
          error -> error
        end
      end,
      use_return: true
    )
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

  defp retry(function, opts \\ []) when is_function(function, 0) do
    Retry.retry with: Retry.DelayStreams.constant_backoff(@retry_delay) |> Stream.take(@max_retries) do
      function.()
    after
      {:ok, value} ->
        case Keyword.get(opts, :use_return, false) do
          true -> value
          false -> :ok
        end
    else
      e ->
        Logger.error(
          "#{__MODULE__} : Timeout limit reached talking to redis, killing Reaper.Scheduler.Supervisor, reason: #{inspect(e)}"
        )

        Supervisor.stop(Reaper.Scheduler.Supervisor, :timeout_limit_reached)
    end
  end

  defp set(key, value) do
    Redix.command(@conn, ["SET", key, value])
  end

  defp delete([]), do: {:ok, nil}

  defp delete(keys) when is_list(keys) do
    Redix.command(@conn, ["DEL" | keys])
  end

  defp delete(key) do
    Redix.command(@conn, ["DEL", key])
  end

  defp keys(key) do
    Redix.command(@conn, ["KEYS", key])
  end

  defp mget(keys) do
    Redix.command(@conn, ["MGET" | keys])
  end

  defp get(key) do
    Redix.command(@conn, ["GET", key])
  end

  defp serialize(job) do
    :erlang.term_to_binary(job)
  end

  defp deserialize(value) do
    :erlang.binary_to_term(value)
  end
end
