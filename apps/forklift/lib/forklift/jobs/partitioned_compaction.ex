defmodule Forklift.Jobs.PartitionedCompaction do
  @moduledoc """
  This job handles compacting files together for long term storage. Running at a long period,
  it takes data out of the main table and then reinserts it to reduce the total number of files in Hive.

  No compaction will be performed if no data is present for the current partition.
  This process assumes that a forklift-managed `os_partition` field is present on the table.
  """
  alias Pipeline.Writer.TableWriter.Helper.PrestigeHelper
  alias Pipeline.Writer.TableWriter.Statement
  require Logger
  import Forklift.Jobs.JobUtils

  def run() do
    Forklift.Quantum.Scheduler.deactivate_job(:data_migrator)

    Forklift.Datasets.get_all!()
    |> Enum.map(&compact/1)
  after
    Forklift.Quantum.Scheduler.activate_job(:data_migrator)
  end

  def compact(nil) do
    Logger.warn("Dataset not found in view-state, skipping compaction")
    :abort
  end

  def compact(%{id: id, technical: %{systemName: system_name}}) do
    partition = current_partition()
    Logger.info("Beginning partitioned compaction for partition #{partition} in dataset #{id}")
    compact_table = compact_table_name(system_name, partition)

    with {:ok, initial_count} <- PrestigeHelper.count(system_name),
         {:ok, partition_count} <-
           PrestigeHelper.count_query("select count(1) from #{system_name} where os_partition = '#{partition}'"),
         {:ok, _} <- pre_check(system_name, compact_table),
         {:ok, _} <- check_for_data_to_compact(partition, partition_count),
         {:ok, _} <- create_compact_table(system_name, partition),
         {:ok, _} <-
           verify_count(compact_table, partition_count, "compact table contains all records from the partition"),
         {:ok, _} <- drop_partition(system_name, partition),
         {:ok, _} <-
           verify_count(
             system_name,
             initial_count - partition_count,
             "main table no longer contains records for the partition"
           ),
         {:ok, _} <- reinsert_compacted_data(system_name, compact_table),
         {:ok, _} <- verify_count(system_name, initial_count, "main table once again contains all records"),
         {:ok, _} <- PrestigeHelper.drop_table(compact_table) do
      Logger.info("Successfully compacted partition #{partition} in dataset #{id}")
      update_compaction_status(id, :ok)
      {:ok, id}
    else
      {:error, error} ->
        Logger.error("Error compacting dataset #{id}: " <> inspect(error))
        update_compaction_status(id, :error)
        {:error, id}

      {:abort, reason} ->
        Logger.info("Aborted compaction of dataset #{id}: " <> reason)
        {:abort, id}
    end
  end

  defp current_partition() do
    Timex.format!(DateTime.utc_now(), "{YYYY}_{0M}")
  end

  defp create_compact_table(table, partition) do
    %{
      table: compact_table_name(table, partition),
      as: "select * from #{table} where os_partition = '#{partition}'"
    }
    |> Statement.create()
    |> elem(1)
    |> PrestigeHelper.execute_query()
  end

  defp drop_partition(table, partition) do
    "delete from #{table} where os_partition = '#{partition}'"
    |> PrestigeHelper.execute_query()
  end

  defp reinsert_compacted_data(table, compact_table) do
    "insert into #{table} select * from #{compact_table}"
    |> PrestigeHelper.execute_query()
  end

  def compact_table_name(table_name, partition) do
    "#{table_name}__#{partition}__compact"
  end

  defp pre_check(table, compact_table) do
    cond do
      PrestigeHelper.table_exists?(table) == false ->
        {:error, "Main table #{table} did not exist"}

      PrestigeHelper.table_exists?(compact_table) ->
        {:error, "Compacted table #{table} still exists"}

      true ->
        {:ok, :passed_pre_check}
    end
  end

  defp check_for_data_to_compact(partition, 0), do: {:abort, "No data found to compact for partition #{partition}"}
  defp check_for_data_to_compact(_partition, _count), do: {:ok, :data_found}

  defp update_compaction_status(dataset_id, :error) do
    TelemetryEvent.add_event_metrics([dataset_id: dataset_id], [:forklift_compaction_failure], value: %{status: 1})
  end

  defp update_compaction_status(dataset_id, :ok) do
    TelemetryEvent.add_event_metrics([dataset_id: dataset_id], [:forklift_compaction_failure], value: %{status: 0})
  end
end
