defmodule Forklift.Jobs.PartitionedCompaction do
  alias Pipeline.Writer.TableWriter.Helper.PrestigeHelper
  alias Pipeline.Writer.TableWriter.Statement
  require Logger
  use Retry.Annotation

  @retries Application.get_env(:forklift, :compaction_retries, 10)
  @backoff Application.get_env(:forklift, :compaction_backoff, 10)

  def run(dataset_ids) do
    Forklift.Quantum.Scheduler.deactivate_job(:insertor)

    dataset_ids
    |> Enum.map(&Forklift.Datasets.get!/1)
    |> Enum.map(&partitioned_compact/1)
  after
    Forklift.Quantum.Scheduler.activate_job(:insertor)
  end

  def partitioned_compact(%{id: id, technical: %{systemName: system_name}}) do
    partition = current_partition()
    # halt json_to_orc job

    # TODO: Metrics for errors
    # TODO: Migrate datasets that don't have os_partition?

    compact_table = compact_table_name(system_name, partition)
    initial_count = PrestigeHelper.count(system_name)

    partition_count =
      PrestigeHelper.count_query("select count(1) from #{system_name} where os_partition = '#{partition}'")

    with {:ok, _} <- pre_check(system_name, compact_table),
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
         {:ok, _} <- verify_count(system_name, initial_count, "main table once again contains all records") do
      PrestigeHelper.drop_table(compact_table)
      update_compaction_status(id, :ok)
      :ok
    else
      {:error, error} ->
        Logger.error("Error compacting dataset #{id}: " <> inspect(error))
        update_compaction_status(id, :error)
        :error

      {:abort, reason} ->
        Logger.warn("Aborted compaction of dataset #{id}: " <> reason)
        :abort
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

  @retry with: constant_backoff(@backoff) |> Stream.take(@retries)
  defp verify_count(table, count, message) do
    actual_count = PrestigeHelper.count(table)

    case actual_count == count do
      true ->
        {:ok, actual_count}

      false ->
        {:error,
         "Table #{table} with count #{actual_count} did not match expected record count of #{count} while trying to verify that #{
           message
         }"}
    end
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
    TelemetryEvent.add_event_metrics([dataset_id: dataset_id], [:compaction_failure], value: %{status: 1})
  end

  defp update_compaction_status(dataset_id, :ok) do
    TelemetryEvent.add_event_metrics([dataset_id: dataset_id], [:compaction_failure], value: %{status: 0})
  end
end
