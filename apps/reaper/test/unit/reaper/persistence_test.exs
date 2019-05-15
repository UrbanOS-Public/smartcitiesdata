defmodule Reaper.RecorderTest do
  use ExUnit.Case
  use Placebo
  alias Reaper.Persistence

  @dataset_id "whatever"
  @timestamp "does not matter"

  test "persists to redis using appropriate prefix" do
    expect Redix.command(:redix, ["SET", "reaper:derived:#{@dataset_id}", any()]), return: nil

    Persistence.record_last_fetched_timestamp(@dataset_id, @timestamp)
  end

  test "retrieves last_processed_index from redis" do
    expect Redix.command!(:redix, ["GET", "reaper:#{@dataset_id}:last_processed_index"]), return: "1"
    Persistence.get_last_processed_index(@dataset_id)
  end

  test "persists last_processed_index to redis" do
    expect Redix.command!(:redix, ["SET", "reaper:#{@dataset_id}:last_processed_index", 1]), return: "OK"
    Persistence.record_last_processed_index(@dataset_id, 1)
  end

  test "deletes last_processed_index from redis" do
    expect Redix.command!(:redix, ["DEL", "reaper:#{@dataset_id}:last_processed_index"]), return: 1
    Persistence.remove_last_processed_index(@dataset_id)
  end

  test "persists to redis json with timestamp" do
    expect Redix.command(:redix, ["SET", any(), "{\"timestamp\": \"#{@timestamp}\"}"]), return: nil

    Persistence.record_last_fetched_timestamp(@dataset_id, @timestamp)
  end
end
