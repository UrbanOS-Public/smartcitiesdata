defmodule Forklift.Compactor do
  require Logger

  @metric_collector Application.get_env(:forklift, :collector)

  def compact_datasets() do
    SmartCity.Dataset.get_all!()
    |> Enum.filter(fn dataset -> dataset.technical.sourceType == "ingest" end)
    |> Enum.map(fn dataset -> compact_dataset(dataset) end)
  end

  def compact_dataset(dataset) do
    system_name = dataset.technical.systemName

    # pause_ingest(dataset.id)
    with :ok <- clear_archive(system_name),
         :ok <- compact_table(system_name),
         :ok <- archive_table(system_name),
         :ok <- rename_compact_table(system_name) do
      Logger.info("#{dataset.id} compacted successfully")
    else
      :error -> :error
    end
  after
    # resume_ingest(dataset.id)
  end

  defp clear_archive(system_name) do
    Prestige.execute("drop table #{system_name}_archive")
    |> Prestige.prefetch()
  end

  defp compact_table(system_name) do
    start_time = Time.utc_now()

    Prestige.execute("create table #{system_name}_compact as (select * from #{system_name})")
    |> Prestige.prefetch()

    duration = Time.diff(Time.utc_now(), start_time, :millisecond)

    record_metrics(system_name, duration)
    Logger.info("Compaction of #{system_name} complete - #{duration}")
  end

  defp archive_table(system_name) do
    Prestige.execute("alter table #{system_name} rename to #{system_name}_archive")
    |> Prestige.prefetch()
  end

  defp rename_compact_table(system_name) do
    Prestige.execute("alter table #{system_name}_compact rename to #{system_name}")
    |> Prestige.prefetch()
  end

  defp record_metrics(dataset_id, time) do
    time
    |> @metric_collector.count_metric("dataset_compaction_duration_total", [
      {"dataset_id", "#{dataset_id}"}
    ])
    |> List.wrap()
    |> @metric_collector.record_metrics("forklift")
    |> case do
      {:ok, _} -> {}
      {:error, reason} -> Logger.warn("Unable to write application metrics: #{inspect(reason)}")
    end
  end
end
