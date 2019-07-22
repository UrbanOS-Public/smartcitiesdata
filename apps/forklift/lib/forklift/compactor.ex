defmodule Forklift.Compactor do
  require Logger

  def compact({dataset, :drop_table}) do
    system_name = dataset.technical.systemName
    # Not sure this will work in forklift, currently cant tables only be dropped by carpenter?
    Prestige.execute("drop table #{system_name}_archive")
    |> Prestige.prefetch()
  end

  def compact({dataset, :compaction}) do
    system_name = dataset.technical.systemName
    start_time = Time.utc_now()

    Prestige.execute("create table #{system_name}_compact as (select * from #{system_name})")
    |> Prestige.prefetch()

    duration = Time.diff(Time.utc_now(), start_time, :millisecond)

    Logger.info("Compaction of #{system_name} complete - #{duration}")
  end

  def compact({dataset, :rename_old}) do
    system_name = dataset.technical.systemName

    Prestige.execute("alter table #{system_name} rename to #{system_name}_archive")
    |> Prestige.prefetch()
  end

  def compact({dataset, :rename_new}) do
    system_name = dataset.technical.systemName

    Prestige.execute("alter table #{system_name}_compact rename to #{system_name}")
    |> Prestige.prefetch()
  end
end
