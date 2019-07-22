defmodule Forklift.Compactor do
  require Logger

  def compact(dataset) do
    # Delete old archive (if it exists)

    # * Create table as

    system_name = dataset.technical.systemName

    #Not sure this will work in forklift, currently cant tables only be dropped by carpenter?
    Prestige.execute("drop table #{system_name}_archive")
    |> Prestige.prefetch()

    Logger.info("Compacting Dataset #{system_name}")

    Prestige.execute("create table #{system_name}_compact as (select * from #{system_name})")
    |> Prestige.prefetch()

    Prestige.execute("alter table #{system_name} rename to #{system_name}_archive")
    |> Prestige.prefetch()

    Prestige.execute("alter table #{system_name}_compact rename to #{system_name}")
    |> Prestige.prefetch()

    Logger.info("Compaction of #{system_name} complete")

    # Rename old table with archive
    # Rename new table to system_name
    # Log time to complete
  end
end
