defmodule Forklift.Compactor do
  require Logger

  @metric_collector Application.get_env(:forklift, :collector)

  def compact_datasets() do
    SmartCity.Dataset.get_all!()
    |> Enum.filter(fn dataset -> dataset.technical.sourceType == "ingest" end)
    |> Enum.map(fn dataset -> compact_dataset(dataset) end)
  end

  def compact_dataset(dataset) do
    pause_ingest(dataset.id)

    dataset.technical.systemName
    |> clear_archive()
    |> compact_table()
    |> archive_table()
    |> rename_compact_table()

    Logger.info("#{dataset.id} compacted successfully")

    resume_ingest(dataset)
  rescue
    e ->
      Logger.error("Unable to compact #{dataset.id}: #{inspect(e)}")
      resume_ingest(dataset)
      :error
  end

  def pause_ingest(dataset_id) do
    with pid when is_pid(pid) <-
           Process.whereis(:"elsa_supervisor_name-integration-#{dataset_id}") do
      DynamicSupervisor.terminate_child(Forklift.Topic.Supervisor, pid)
    else
      nil -> :ok
    end
  end

  def resume_ingest(dataset) do
    Forklift.Datasets.DatasetHandler.handle_dataset(dataset)
  end

  defp clear_archive(system_name) do
    Prestige.execute("drop table if exists #{system_name}_archive")
    |> Prestige.prefetch()

    system_name
  end

  defp compact_table(system_name) do
    start_time = Time.utc_now()

    Prestige.execute("create table #{system_name}_compact as (select * from #{system_name})")
    |> Prestige.prefetch()

    duration = Time.diff(Time.utc_now(), start_time, :millisecond)

    record_metrics(system_name, duration)
    Logger.info("Compaction of #{system_name} complete - #{duration}")

    system_name
  end

  defp archive_table(system_name) do
    Prestige.execute("alter table #{system_name} rename to #{system_name}_archive")
    |> Prestige.prefetch()

    system_name
  end

  defp rename_compact_table(system_name) do
    Prestige.execute("alter table #{system_name}_compact rename to #{system_name}")
    |> Prestige.prefetch()

    system_name
  rescue
    e ->
      Logger.error("Unable to rename compacted table #{system_name}, restoring archive table")

      Prestige.execute("alter table #{system_name}_archive rename to #{system_name}")
      |> Prestige.prefetch()

      reraise e, __STACKTRACE__
  end

  defp record_metrics(system_name, time) do
    time
    |> @metric_collector.count_metric("dataset_compaction_duration_total", [
      {"system_name", "#{system_name}"}
    ])
    |> List.wrap()
    |> @metric_collector.record_metrics("forklift")
    |> case do
      {:ok, _} -> {}
      {:error, reason} -> Logger.warn("Unable to write application metrics: #{inspect(reason)}")
    end
  end
end
