defmodule CacheClientTest do
  use ExUnit.Case
  use Placebo

  alias SmartCity.TestDataGenerator, as: TDG

  alias Forklift.CacheClient
  @cache_processing_batch_size Application.get_env(:forklift, :cache_processing_batch_size)

  test "inserts into redis" do
    message = TDG.create_data(dataset_id: "ds1") |> Jason.encode!()
    offset = 5
    dataset_id = "cota"

    key = "forklift:dataset:#{dataset_id}:#{offset}"
    expect(Redix.command!(any(), ["SET", key, message]), return: :ok)

    CacheClient.write(message, dataset_id, offset)
  end

  test "reads all data messages from redis" do
    keys = ["forklift:dataset:key1:5", "forklift:dataset:key2:6"]
    values = ["v1", "v2"]

    allow(
      Redix.command!(any(), [
        "SCAN",
        0,
        "MATCH",
        "forklift:dataset:*",
        "COUNT",
        @cache_processing_batch_size
      ]),
      return: ["0", keys]
    )

    allow(Redix.command!(any(), ["GET", Enum.at(keys, 0)]), return: Enum.at(values, 0))
    allow(Redix.command!(any(), ["GET", Enum.at(keys, 1)]), return: Enum.at(values, 1))

    expected = [
      {"forklift:dataset:key1:5", "v1"},
      {"forklift:dataset:key2:6", "v2"}
    ]

    assert CacheClient.read_all_batched_messages() == expected
  end

  test "deletes records given a list of keys" do
    keys = ["forklift:dataset:key1:5", "forklift:dataset:key2:6"]
    expect(Redix.command!(any(), ["DEL" | keys]), return: :ok)

    CacheClient.delete(keys)
  end

  test "deletes records given a single key" do
    key = "forklift:dataset:key2:6"
    expect(Redix.command!(any(), ["DEL", key]), return: :ok)

    CacheClient.delete(key)
  end
end
