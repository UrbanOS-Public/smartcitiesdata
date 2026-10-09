defmodule DiscoveryApi.Instrumentation.MemoryReporter do
  @moduledoc """
  Periodically logs BEAM-level resource counters so a slow, multi-day memory
  climb (e.g. leading to an OOMKill) can be correlated against which
  specific resource is actually growing - total process count, binary/ETS/
  atom memory, and the size of the dedicated Raptor hackney pool - instead of
  being inferred after the fact from crash volume in the request logs, which
  is all that was available to diagnose the original incident.

  Deliberately dependency-free (no :recon/:observer_cli): everything here
  comes from :erlang builtins and hackney_pool, both already present, kept
  cheap enough to run on a short interval indefinitely in production.

  Every line is tagged "MemoryReporter:" and emitted as a single
  Logger.info/1 call with a flat keyword list, so a log pipeline can grep/
  parse it without special handling.
  """
  use GenServer
  use Properties, otp_app: :discovery_api
  require Logger

  getter(:interval_ms, generic: true, default: 60_000)

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(_opts) do
    schedule_report(0)
    {:ok, %{}}
  end

  @impl GenServer
  def handle_info(:report, state) do
    report()
    schedule_report(interval_ms())
    {:noreply, state}
  end

  defp schedule_report(delay) do
    Process.send_after(self(), :report, delay)
  end

  defp report do
    memory = :erlang.memory()

    Logger.info(
      "MemoryReporter: " <>
        inspect(
          process_count: :erlang.system_info(:process_count),
          process_limit: :erlang.system_info(:process_limit),
          port_count: :erlang.system_info(:port_count),
          atom_count: :erlang.system_info(:atom_count),
          atom_limit: :erlang.system_info(:atom_limit),
          ets_table_count: :erlang.system_info(:ets_count),
          memory_total: memory[:total],
          memory_processes: memory[:processes],
          memory_binary: memory[:binary],
          memory_ets: memory[:ets],
          memory_atom: memory[:atom],
          memory_code: memory[:code],
          raptor_pool: raptor_pool_stats()
        )
    )
  rescue
    error -> Logger.warn("MemoryReporter: failed to collect stats: #{inspect(error)}")
  end

  defp raptor_pool_stats do
    case :hackney_pool.find_pool(:raptor_http_pool) do
      :undefined ->
        :not_started

      _pid ->
        :hackney_pool.get_stats(:raptor_http_pool)
    end
  catch
    kind, reason -> {:unavailable, kind, reason}
  end
end
