defmodule Forklift.Jobs.PartitionedCompaction do
  alias Pipeline.Writer.TableWriter.Helper.PrestigeHelper
  alias Pipeline.Writer.TableWriter.Statement

  def run(dataset_ids) do
    dataset_ids
    |> Enum.map(&Forklift.Datasets.get!/1)
    |> Enum.map(&partitioned_compact/1)
  end

  def partitioned_compact(%{technical: %{systemName: system_name}}) do
    partition = current_partition()
    # halt json_to_orc job

    initial_count = PrestigeHelper.count(system_name)

    # create new table as select entire partition
    create_compact_table(system_name, partition)

    # drop partition from original table
    drop_partition(system_name, partition)

    # reinsert entire partition
    reinsert_compacted_data(system_name)

    # validate count remains the same
    new_count = PrestigeHelper.count(system_name)
    if new_count != initial_count do
      "Panic" |> IO.inspect(label: "partitioned_compaction.ex:29")
    end

    # drop compacted table
    PrestigeHelper.drop_table(system_name <> "__compact")

    # resume halted bits
  end

  defp current_partition() do
    Timex.format!(DateTime.utc_now(), "{YYYY}_{0M}")
  end

  defp create_compact_table(table, partition) do
    %{
      table: table <> "__compact",
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
    "insert into #{table} select * from #{table}__compact"
    |> PrestigeHelper.execute_query()
  end
end
