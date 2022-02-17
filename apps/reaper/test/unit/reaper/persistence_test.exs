defmodule Reaper.RecorderTest do
  use ExUnit.Case
  use Placebo
  alias Reaper.Persistence

  @ingestion_id "whatever"
  @timestamp "does not matter"
  @redix Reaper.Application.redis_client()

  test "persists to redis using appropriate prefix" do
    expect Redix.command(@redix, ["SET", "reaper:derived:#{@ingestion_id}", any()]), return: nil

    Persistence.record_last_fetched_timestamp(@ingestion_id, @timestamp)
  end

  test "retrieves last_processed_index from redis" do
    expect Redix.command!(@redix, ["GET", "reaper:#{@ingestion_id}:last_processed_index"]), return: "1"
    Persistence.get_last_processed_index(@ingestion_id)
  end

  test "persists last_processed_index to redis" do
    expect Redix.command!(@redix, ["SET", "reaper:#{@ingestion_id}:last_processed_index", 1]), return: "OK"
    Persistence.record_last_processed_index(@ingestion_id, 1)
  end

  test "deletes last_processed_index from redis" do
    expect Redix.command!(@redix, ["DEL", "reaper:#{@ingestion_id}:last_processed_index"]), return: 1
    Persistence.remove_last_processed_index(@ingestion_id)
  end

  test "persists to redis json with timestamp" do
    expect Redix.command(@redix, ["SET", any(), "{\"timestamp\": \"#{@timestamp}\"}"]), return: nil

    Persistence.record_last_fetched_timestamp(@ingestion_id, @timestamp)
  end
end
