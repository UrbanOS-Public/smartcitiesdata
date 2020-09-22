defmodule Forklift.Jobs.PartitionedCompaction do
  alias Pipeline.Writer.TableWriter.Helper.PrestigeHelper
  alias Pipeline.Writer.TableWriter.Statement
  require Logger

  def run(dataset_ids) do
    dataset_ids
    |> Enum.map(&Forklift.Datasets.get!/1)
    |> Enum.map(&partitioned_compact/1)
  end

  def partitioned_compact(%{id: id, technical: %{systemName: system_name}}) do
    partition = current_partition()
    # halt json_to_orc job
    # Forklift.Quantum.Scheduler.deactivate_job(:insertor)
    # TODO: These are undefined in the test/integration environments. Mock them?
    # TODO: If main table and compact table (for partition) exist, abort and put a metric on prometheus
    # TODO: Add protections for known compaction issues
    # TODO: Abort if no data exists for the partition
    # TODO: Handle edge cases where two partitions might need compacted (always compact current + previous?)

    compact_table = compact_table_name(system_name, partition)
    initial_count = PrestigeHelper.count(system_name)

    partition_count =
      PrestigeHelper.count_query("select count(1) from #{system_name} where os_partition = '#{partition}'")

    with {:ok, _} <- pre_check(system_name, compact_table),
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
      :ok
    else
      {:error, error} ->
        Logger.error("Error compacting dataset #{id}: " <> inspect(error))
        :error

      {:abort, reason} ->
        Logger.warn("Aborted compaction of dataset #{id}: " <> reason)
        :abort
    end

    # resume halted bits
    # Forklift.Quantum.Scheduler.reactivate_job(:insertor)
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
    "#{table_name}__#{partition}__compact" # TODO: Add partition to this
  end

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
        {:abort, "Main table #{table} did not exist"}
      PrestigeHelper.table_exists?(compact_table) ->
        {:abort, "Compacted table #{table} still exists"}
      true ->
        {:ok, :passed_pre_check}
    end
  end
end
