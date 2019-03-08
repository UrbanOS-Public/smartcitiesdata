defmodule Reaper.RecorderTest do
  use ExUnit.Case
  use Placebo
  alias Reaper.Persistence

  @dataset_id "whatever"
  @timestamp "does not matter"

  test "when given the an empty list of dataset records, it does not record to redis" do
    allow Redix.command(any(), any()), return: nil

    Persistence.record_last_fetched_timestamp([], @dataset_id, @timestamp)

    assert not called?(Redix.command(any(), any()))
  end

  test "when valid, persist to redis using appropriate prefix" do
    records = [
      {:ok, %{vehicle_id: 1, description: "whatever"}}
    ]

    expect Redix.command(:redix, ["SET", "reaper:derived:#{@dataset_id}", any()]), return: nil

    Persistence.record_last_fetched_timestamp(records, @dataset_id, @timestamp)
  end

  test "when valid, persist to redis json with timestamp" do
    records = [
      {:ok, %{vehicle_id: 1, description: "whatever"}}
    ]

    expect Redix.command(:redix, ["SET", any(), "{\"timestamp\": \"#{@timestamp}\"}"]), return: nil

    Persistence.record_last_fetched_timestamp(records, @dataset_id, @timestamp)
  end

  test "when given the list of dataset records with no failures, it records to redis" do
    records = [
      {:ok, %{vehicle_id: 1, description: "whatever"}},
      {:ok, %{vehicle_id: 2, description: "more stuff"}}
    ]

    expect Redix.command(any(), any()), return: nil

    Persistence.record_last_fetched_timestamp(records, @dataset_id, @timestamp)
  end

  test "when given the list of dataset records with a single failure, it records to redis" do
    records = [
      {:ok, %{vehicle_id: 1, description: "whatever"}},
      {:error, "failed to load into kafka"}
    ]

    expect Redix.command(any(), any()), return: nil

    Persistence.record_last_fetched_timestamp(records, @dataset_id, @timestamp)
  end

  test "when given the list of dataset records with all failures (something is really wrong), it does not record to redis" do
    records = [
      {:error, "failed to load into kafka"},
      {:error, "failed to load into kafka"}
    ]

    allow Redix.command(any(), any()), return: nil

    Persistence.record_last_fetched_timestamp(records, @dataset_id, @timestamp)

    assert not called?(Redix.command(any(), any()))
  end
end
