defmodule RedisClientTest do
  use ExUnit.Case
  use Placebo

  alias Forklift.RedisClient

  test "inserts into redis" do
    message = Mockaffe.create_message(:data, :basic) |> Jason.encode!()
    offset = 5
    dataset_id = "cota"

    key = "forklift:dataset:#{dataset_id}:#{offset}"
    expect(Redix.command!(any(), ["SET", key, message]), return: :ok)

    RedisClient.write(message, dataset_id, offset)
  end

  test "reads all data messages from redis" do
    keys = ["forklift:dataset:key1:5", "forklift:dataset:key2:6"]
    values = ["v1", "v2"]
    allow(Redix.command!(any(), ["KEYS", "forklift:dataset:*"]), return: keys)
    allow(Redix.command!(any(), ["GET", Enum.at(keys, 0)]), return: Enum.at(values, 0))
    allow(Redix.command!(any(), ["GET", Enum.at(keys, 1)]), return: Enum.at(values, 1))

    expected = [
      {"forklift:dataset:key1:5", "v1"},
      {"forklift:dataset:key2:6", "v2"}
    ]

    assert RedisClient.read_all_batched_messages() == expected
  end

  test "deletes records given a list of keys" do
    keys = ["forklift:dataset:key1:5", "forklift:dataset:key2:6"]
    expect(Redix.command!(any(), ["DEL" | keys]), return: :ok)

    RedisClient.delete(keys)
  end
end
