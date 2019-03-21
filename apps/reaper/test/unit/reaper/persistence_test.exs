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

  test "persists to redis json with timestamp" do
    expect Redix.command(:redix, ["SET", any(), "{\"timestamp\": \"#{@timestamp}\"}"]), return: nil

    Persistence.record_last_fetched_timestamp(@dataset_id, @timestamp)
  end
end
