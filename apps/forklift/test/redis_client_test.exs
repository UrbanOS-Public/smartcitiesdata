defmodule RedisClientTest do
  use ExUnit.Case
  use Placebo

  alias Forklift.RedisClient

  test "inserts into redis" do
    message = Mockaffe.create_message(:data, :basic) |> Jason.encode!()
    offset = 5
    dataset_id = "cota"

    key = "forklift:dataset:#{dataset_id}:#{offset}"
    expect(Redix.command(any(), ["SET", key, message]), return: :ok)

    RedisClient.write(message, dataset_id, offset)
  end
end
