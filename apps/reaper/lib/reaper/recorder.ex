defmodule Reaper.Recorder do
  @moduledoc """
  Records last used time to redis
  """
  @name_space "reaper:derived:"
  def record_last_fetched_timestamp([_ | _] = records, dataset_id, timestamp) do
    success = Enum.any?(records, fn {status, _} -> status == :ok end)

    if success do
      Redix.command(:redix, ["SET", "#{@name_space}#{dataset_id}", "{\"timestamp\": \"#{timestamp}\"}"])
    end
  end

  def record_last_fetched_timestamp(_records, _dataset_id, _timestamp), do: nil
end
