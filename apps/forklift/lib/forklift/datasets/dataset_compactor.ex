defmodule Forklift.Datasets.DatasetCompactor do
  @moduledoc """
  Because Forklift inserts data as it receives it, and Presto creates a new partfile for each insert, Presto is left with a large number of files which slows reads from the table.

  This module cleans up the fragmentation caused by this process.
  """
  require Logger

  # Carpenter creates tables, and is the only one who can delete them
  @module_user "carpenter"

  @metric_collector Application.get_env(:forklift, :collector)

  def compact_datasets() do
    Logger.info("Beginning scheduled dataset compaction")

    SmartCity.Dataset.get_all!()
    |> Enum.filter(fn dataset ->
      dataset.technical.sourceType == "ingest" || dataset.technical.sourceType == "stream"
    end)
    |> Enum.map(fn dataset -> {dataset.technical.systemName, compact_dataset(dataset)} end)
    |> Enum.each(fn {system_name, status} -> Logger.info("#{system_name} -> #{status}") end)

    :ok
  end

  def compact_dataset(dataset) do
    pause_ingest(dataset.id)

    cleanup_old_table(dataset.id, dataset.technical.systemName)
    compact_table(dataset.id, dataset.technical.systemName)

    Logger.info("#{dataset.id}: compacted successfully")

    resume_ingest(dataset)
  rescue
    e ->
      Logger.error("#{dataset.id}: compacting raised: #{inspect(e)}")
      resume_ingest(dataset)
      :error
  end

  def pause_ingest(dataset_id) do
    Logger.info("#{dataset_id}: Pausing ingest")
    prefix = Application.get_env(:forklift, :data_topic_prefix)

    case Process.whereis(:"elsa_supervisor_name-#{prefix}-#{dataset_id}") do
      pid when is_pid(pid) ->
        DynamicSupervisor.terminate_child(Forklift.Topic.Supervisor, pid)

      _ ->
        :ok
    end
  end

  def resume_ingest(dataset) do
    Logger.info("#{dataset.id}: Resuming ingest")

    case Forklift.Datasets.DatasetHandler.handle_dataset(dataset) do
      {:ok, _pid} ->
        :ok

      {:error, {:already_started, _pid}} ->
        Logger.warn(
          "Dataset #{dataset.id} was compacted while Forklift was still subscribed to its topic. This can result in the loss of data."
        )

        :ok

      e ->
        Logger.error("Failed to resume ingest of dataset #{dataset.id} with unhandled error: #{inspect(e)}")

        :error
    end
  end

  defp cleanup_old_table(dataset_id, system_name) do
    Logger.info("#{dataset_id}: Dropping compact table for #{system_name}")
    execute_as_module_user("drop table if exists #{system_name}_compact")
  end

  defp compact_table(dataset_id, system_name) do
    start_time = Time.utc_now()

    compact_task =
      Task.async(fn ->
        safe_execute_as_module_user(dataset_id, "create table #{system_name}_compact as (select * from #{system_name})")
      end)

    [[original_count]] =
      Task.async(fn -> safe_execute_as_module_user(dataset_id, "select count(1) from #{system_name}") end)
      |> Task.await(:infinity)

    Task.await(compact_task, :infinity)

    [[compacted_count]] = execute_as_module_user("select count(1) from #{system_name}_compact")

    if original_count == compacted_count do
      drop_original_table(dataset_id, system_name)
      rename_compact_table(dataset_id, system_name)

      duration = Time.diff(Time.utc_now(), start_time, :millisecond)

      record_metrics(dataset_id, system_name, duration)
      Logger.info("#{dataset_id}: Compaction of #{system_name} complete - #{duration}")
      :ok
    else
      cleanup_old_table(dataset_id, system_name)

      error_message =
        "#{dataset_id}: Compaction of #{system_name} failed. Original rows #{original_count} do not match compacted rows: #{
          compacted_count
        }"

      Logger.error(error_message)
      raise error_message
    end
  end

  defp drop_original_table(dataset_id, system_name) do
    Logger.info("#{dataset_id}: Dropping original table #{system_name}")
    execute_as_module_user("drop table #{system_name}")
  end

  defp rename_compact_table(dataset_id, system_name) do
    Logger.info("#{dataset_id}: Renaming table")
    execute_as_module_user("alter table #{system_name}_compact rename to #{system_name}")
  rescue
    e ->
      Logger.error("#{dataset_id}: Unable to rename compacted table #{system_name}")
      reraise e, __STACKTRACE__
  end

  defp record_metrics(dataset_id, system_name, time) do
    Logger.info("#{dataset_id}: Recording metrics")

    time
    |> @metric_collector.count_metric("dataset_compaction_duration_total", [
      {"system_name", "#{system_name}"}
    ])
    |> List.wrap()
    |> @metric_collector.record_metrics("forklift")
    |> case do
      {:ok, _} -> {}
      {:error, reason} -> Logger.warn("#{dataset_id}: Unable to write application metrics: #{inspect(reason)}")
    end
  end

  defp safe_execute_as_module_user(dataset_id, statement) do
    execute_as_module_user(statement)
  rescue
    e -> Logger.error("#{dataset_id}: Statement #{statement} failed to properly execute: #{inspect(e)}")
  end

  defp execute_as_module_user(statement) do
    statement
    |> Prestige.execute(user: @module_user)
    |> Prestige.prefetch()
  end
end
