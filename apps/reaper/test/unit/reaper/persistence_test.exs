defmodule Reaper.RecorderTest do
  use ExUnit.Case
  import Mox
  alias Reaper.Persistence

  setup :verify_on_exit!

  @ingestion_id "whatever"
  @timestamp "does not matter"
  @redix Reaper.Application.redis_client()

  test "persists to redis using appropriate prefix" do
    expect(RedixMock, :command, fn @redix, ["SET", "reaper:derived:" <> @ingestion_id, _] -> nil end)

    Persistence.record_last_fetched_timestamp(@ingestion_id, @timestamp)
  end

  test "retrieves last_processed_index from redis" do
    expect(RedixMock, :command!, fn @redix, ["GET", "reaper:" <> @ingestion_id <> ":last_processed_index"] -> "1" end)
    Persistence.get_last_processed_index(@ingestion_id)
  end

  test "persists last_processed_index to redis" do
    expect(RedixMock, :command!, fn @redix, ["SET", "reaper:" <> @ingestion_id <> ":last_processed_index", 1] -> "OK" end)
    Persistence.record_last_processed_index(@ingestion_id, 1)
  end

  test "deletes last_processed_index from redis" do
    expect(RedixMock, :command!, fn @redix, ["DEL", "reaper:" <> @ingestion_id <> ":last_processed_index"] -> 1 end)
    Persistence.remove_last_processed_index(@ingestion_id)
  end

  test "persists to redis json with timestamp" do
    expect(RedixMock, :command, fn @redix, ["SET", _, "{\"timestamp\": \"" <> @timestamp <> "\"}"] -> nil end)

    Persistence.record_last_fetched_timestamp(@ingestion_id, @timestamp)
  end
end
