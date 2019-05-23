defmodule Reaper.Recorder do
  @moduledoc """
  Records last fetched time to Redis
  """
  @name_space "reaper:derived:"
  @doc """
  Persists the last fetched timestamp to Redis
  """
  @spec record_last_fetched_timestamp(list(), pos_integer(), String.t()) ::
          {:ok, String.t()} | {:error, String.t()}
  def record_last_fetched_timestamp([_ | _] = records, dataset_id, timestamp) do
    success = Enum.any?(records, fn {status, _} -> status == :ok end)

    if success do
      Redix.command(:redix, [
        "SET",
        "#{@name_space}#{dataset_id}",
        "{\"timestamp\": \"#{timestamp}\"}"
      ])
    end
  end

  def record_last_fetched_timestamp(_records, _dataset_id, _timestamp), do: nil
end
