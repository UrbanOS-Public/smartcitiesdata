defmodule Reaper.Migrations do
  @moduledoc """
  Contains all migrations that run during bootup.
  """
  use GenServer, restart: :transient
  use Properties, otp_app: :reaper

  require Logger

  @instance_name Reaper.instance_name()

  getter(:brook, generic: true)

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    Logger.info("======================================================")
    Logger.info("Reaper.Migrations starting...")
    Logger.info("======================================================")

    # Verify :pg module is available (part of kernel application in OTP 23+)
    if Code.ensure_loaded?(:pg) do
      Logger.info("Reaper.Migrations: :pg module is available and loaded")
    else
      Logger.error("Reaper.Migrations: CRITICAL - :pg module is NOT available!")
    end

    Logger.info("Reaper.Migrations: Starting Brook instance for migrations...")

    case start_brook() do
      {:ok, brook} ->
        Logger.info("Reaper.Migrations: Brook started successfully (pid: #{inspect(brook)})")

        migrate_enabled_flag()

        stop_brook(brook)

        {:ok, quantum} = start_quantum_storage()

        migrate_quantum_task()

        stop_quantum_storage(quantum)

        Logger.info("======================================================")
        Logger.info("Reaper.Migrations completed successfully")
        Logger.info("======================================================")

        {:ok, :ok, {:continue, :stop}}

      {:error, reason} = error ->
        Logger.error("======================================================")
        Logger.error("Reaper.Migrations: FAILED to start Brook: #{inspect(reason)}")
        Logger.error("======================================================")
        {:stop, reason}
    end
  end

  defp start_brook() do
    brook_config =
      brook()
      |> Keyword.put(:instance, @instance_name)
      |> Keyword.delete(:driver)

    Logger.debug("Reaper.Migrations: Brook config: #{inspect(brook_config)}")

    result = Brook.start_link(brook_config)

    case result do
      {:ok, pid} ->
        Logger.info("Reaper.Migrations: Brook.start_link succeeded (pid: #{inspect(pid)})")

      {:error, {:already_started, pid}} ->
        Logger.warn("Reaper.Migrations: Brook already started (pid: #{inspect(pid)})")

      {:error, reason} ->
        Logger.error("Reaper.Migrations: Brook.start_link failed: #{inspect(reason)}")
    end

    result
  end

  defp stop_brook(brook) do
    Process.unlink(brook)
    Supervisor.stop(brook)
  end

  defp start_quantum_storage() do
    Application.get_env(:reaper, Reaper.Quantum.Storage, [])
    |> Reaper.Quantum.Storage.Connection.start_link()
  end

  defp stop_quantum_storage(quantum) do
    Process.unlink(quantum)
    Process.exit(quantum, :kill)
  end

  def handle_continue(:stop, state) do
    {:stop, :normal, state}
  end

  defp migrate_enabled_flag() do
    Brook.get_all_values!(@instance_name, :extractions)
    |> Enum.each(&migrate_extractions/1)
  end

  defp migrate_extractions(%{"enabled" => _enabled}) do
    Logger.info("Nothing to migrate")
  end

  defp migrate_extractions(%{"ingestion" => %{id: ingestion_id}}) do
    Logger.info("Migrating : #{ingestion_id}")

    Brook.Test.with_event(
      @instance_name,
      Brook.Event.new(type: "reaper_config:migration", author: "migration", data: ingestion_id),
      fn ->
        Brook.ViewState.merge(:extractions, ingestion_id, %{"enabled" => true})
      end
    )
  end

  defp migrate_extractions(_ingestion) do
    Logger.info("Nothing to migrate")
  end

  defp migrate_quantum_task() do
    Reaper.Quantum.Storage.jobs(Reaper.Scheduler)
    |> case do
      :not_applicable -> :ok
      jobs -> Enum.each(jobs, &migrate_brook_args/1)
    end
  end

  defp migrate_brook_args(%{name: name, task: {Brook.Event, :send, args}} = job) do
    case length(args) do
      3 ->
        Reaper.Quantum.Storage.delete_job(Reaper.Scheduler, name)

        updated_job = update_task(job)
        Reaper.Quantum.Storage.add_job(Reaper.Scheduler, updated_job)

      _ ->
        :ok
    end
  end

  defp migrate_brook_args(_), do: :ok

  defp update_task(%{task: {Brook.Event, :send, args}} = job) do
    new_args = [@instance_name | args]
    %{job | task: {Brook.Event, :send, new_args}}
  end
end
