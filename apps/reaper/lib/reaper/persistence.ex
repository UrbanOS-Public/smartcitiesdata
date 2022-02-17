defmodule Reaper.Persistence do
  @moduledoc """
  This module provides functionality for interacting with Redis
  """

  @name_space_derived "reaper:derived:"
  @redix Reaper.Application.redis_client()

  @doc """
  Update the timestamp of when data was last fetched for a ingestion_id in Redis
  """
  @spec record_last_fetched_timestamp(String.t(), DateTime.t()) ::
          {:ok, String.t()} | {:error, String.t()}
  def record_last_fetched_timestamp(ingestion_id, timestamp) do
    Redix.command(@redix, [
      "SET",
      @name_space_derived <> ingestion_id,
      ~s({"timestamp": "#{timestamp}"})
    ])
  end

  def remove_last_fetched_timestamp(ingestion_id) do
    Redix.command(@redix, ["DEL", @name_space_derived <> ingestion_id])
  end

  def get_last_processed_index(ingestion_id) do
    case Redix.command!(@redix, ["GET", "reaper:#{ingestion_id}:last_processed_index"]) do
      nil -> -1
      last_processed_index -> String.to_integer(last_processed_index)
    end
  end

  def record_last_processed_index(ingestion_id, index) do
    Redix.command!(@redix, ["SET", "reaper:#{ingestion_id}:last_processed_index", index])
  end

  def remove_last_processed_index(ingestion_id) do
    Redix.command!(@redix, ["DEL", "reaper:#{ingestion_id}:last_processed_index"])
  end

  @doc """
  Retrieve the timestamp of when data was last fetched for an ingestion_id from Redis
  """
  @spec get_last_fetched_timestamp(String.t()) :: DateTime.t() | nil
  def get_last_fetched_timestamp(ingestion_id) do
    json = Redix.command!(@redix, ["GET", @name_space_derived <> ingestion_id])
    extract_timestamp(json)
  end

  defp extract_timestamp(nil), do: nil

  defp extract_timestamp(json) do
    {:ok, timestamp, _offset} =
      json
      |> Jason.decode!()
      |> Map.get("timestamp")
      |> DateTime.from_iso8601()

    timestamp
  end
end
