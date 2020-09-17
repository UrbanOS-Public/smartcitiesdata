defmodule Forklift.Jobs.PartitionedCompaction do
  def run(dataset_ids) do
    # halt json_to_orc job

    # create new table as select entire partition

    # drop partition from original table

    # reinsert entire partition

    # validate count remains the same

    # resume halted bits
  end
end
