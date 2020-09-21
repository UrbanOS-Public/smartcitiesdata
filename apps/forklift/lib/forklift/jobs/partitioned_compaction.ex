defmodule Forklift.Jobs.PartitionedCompaction do
  alias Pipeline.Writer.TableWriter.Helper.PrestigeHelper
  alias Pipeline.Writer.TableWriter.Statement
  require Logger

  def run(dataset_ids) do
    dataset_ids
    |> Enum.map(&Forklift.Datasets.get!/1)
    |> Enum.map(&partitioned_compact/1)
  end

  def partitioned_compact(%{technical: %{systemName: system_name}}) do
    partition = current_partition()
    # halt json_to_orc job
    # Forklift.Quantum.Scheduler.deactivate_job(:insertor)
    # TODO: These are undefined in the test/integration environments. Mock them?

    compact_table = compact_table_name(system_name)
    initial_count = PrestigeHelper.count(system_name)

    partition_count =
      PrestigeHelper.count_query("select count(1) from #{system_name} where os_partition = '#{partition}'")

    with {:ok, _} <- create_compact_table(system_name, partition),
         :ok <- verify_count(compact_table, partition_count),
         {:ok, _} <- drop_partition(system_name, partition),
         :ok <- verify_count(system_name, initial_count - partition_count),
         {:ok, _} <- reinsert_compacted_data(system_name),
         :ok <- verify_count(system_name, initial_count) do
      # drop compacted table
      PrestigeHelper.drop_table(compact_table_name(system_name))
      :ok
    else
      {:error, error} ->
        Logger.error("Error compacting table #{system_name}: " <> inspect(error))
        :error

      :error ->
        :error
    end

    # resume halted bits
    # Forklift.Quantum.Scheduler.reactivate_job(:insertor)
  end

  defp current_partition() do
    Timex.format!(DateTime.utc_now(), "{YYYY}_{0M}")
  end

  defp create_compact_table(table, partition) do
    %{
      table: compact_table_name(table),
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

  defp reinsert_compacted_data(table) do
    "insert into #{table} select * from #{compact_table_name(table)}"
    |> PrestigeHelper.execute_query()
  end

  defp compact_table_name(table_name) do
    table_name <> "__compact"
  end

  defp verify_count(table, count) do
    case PrestigeHelper.count(table) == count do
      true -> :ok
      false -> {:error, "Table #{table} did not match expected record count of #{count}"}
    end
  end
end
