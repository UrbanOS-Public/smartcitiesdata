defmodule Forklist.DataBufferIntTest do
  use ExUnit.Case
  use Divo, services: [:kafka, :redis]

  alias SmartCity.Data
  alias Forklift.DataBuffer
  alias SmartCity.TestDataGenerator, as: TDG

  @redis Forklift.Application.redis_client()

  setup do
    @redis.command!(["FLUSHALL"])
    :ok
  end

  test "write/1 adds message to redis stream" do
    data = TDG.create_data(dataset_id: "ds1", payload: %{one: 1, two: 2})

    DataBuffer.write(data)

    key = "forklift:data:#{data.dataset_id}"
    [["forklift:data:ds1", [[_key, ["message", actual]]]]] = @redis.command!(["XREAD", "STREAMS", key, "0"])
    assert data == ok(Data.new(actual))
  end

  test "get_pending_datasets/0 returns keys of all existing data streams" do
    data1 = TDG.create_data(dataset_id: "ds1")
    data2 = TDG.create_data(dataset_id: "ds2")
    data3 = TDG.create_data(dataset_id: "64da2b7d-189e-48a3-8ff3-86e03bc4feef")
    DataBuffer.write(data1)
    DataBuffer.write(data2)
    DataBuffer.write(data3)

    actual = DataBuffer.get_pending_datasets()

    assert MapSet.new(["ds1", "ds2", "64da2b7d-189e-48a3-8ff3-86e03bc4feef"]) == MapSet.new(actual)
  end

  test "get_pending_data/1 returns messages that have not been read by group yet" do
    [data1, data2] = TDG.create_data([dataset_id: "ds1", payload: %{one: 1, two: 2}], 2)
    {:ok, data1_key} = DataBuffer.write(data1)
    {:ok, data2_key} = DataBuffer.write(data2)

    assert [%{key: data1_key, data: data1}, %{key: data2_key, data: data2}] == DataBuffer.get_pending_data("ds1")
  end

  test "get_pending_data/1 returns non acked messages and new messages" do
    [data1, data2] = TDG.create_data([dataset_id: "ds1", payload: %{one: 1, two: 2}], 2)
    {:ok, data1_key} = DataBuffer.write(data1)
    {:ok, _data2_key} = DataBuffer.write(data2)

    [_actual1, actual2] = DataBuffer.get_pending_data("ds1")
    DataBuffer.mark_complete("ds1", [actual2])

    [data3, data4] = TDG.create_data([dataset_id: "ds1", payload: %{one: 1, two: 2}], 2)
    {:ok, data3_key} = DataBuffer.write(data3)
    {:ok, data4_key} = DataBuffer.write(data4)

    expected = [%{key: data1_key, data: data1}, %{key: data3_key, data: data3}, %{key: data4_key, data: data4}]
    assert expected == DataBuffer.get_pending_data("ds1")
  end

  test "mark_complete/1 acks and deletes messages for consumer group" do
    [data1, data2, data3] = TDG.create_data([dataset_id: "ds1", payload: %{one: 1, two: 2}], 3)
    DataBuffer.write(data1)
    DataBuffer.write(data2)
    DataBuffer.write(data3)
    [_actual1, actual2, actual3] = DataBuffer.get_pending_data("ds1")

    :ok = DataBuffer.mark_complete("ds1", [actual2, actual3])

    response = @redis.command!(["XREADGROUP", "GROUP", "forklift", "consumer1", "STREAMS", "forklift:data:ds1", "0"])

    [["forklift:data:ds1", [[_key, ["message", pending]]]]] = response
    assert data1 == ok(Data.new(pending))

    response = @redis.command!(["XREAD", "STREAMS", "forklift:data:ds1", "0"])
    [["forklift:data:ds1", [[_key, ["message", pending]]]]] = response
    assert data1 == ok(Data.new(pending))
  end

  test "cleanup_dataset/2 does not delete the stream if no messages read last 1 time" do
    data = TDG.create_data(dataset_id: "ds100")
    DataBuffer.write(data)

    DataBuffer.cleanup_dataset("ds100", [])

    assert @redis.command!(["EXISTS", "forklift:data:ds100"]) == 1
  end

  test "cleanup_dataset/2 deletes the stream when no messages have been read for awhile" do
    data = TDG.create_data(dataset_id: "ds101")
    {:ok, key} = DataBuffer.write(data)
    number_of_empty_reads = Application.get_env(:forklift, :number_of_empty_reads_to_delete, 50)

    DataBuffer.mark_complete("ds101", [%{key: key, data: data}])

    0..(number_of_empty_reads + 1)
    |> Enum.each(fn _ -> DataBuffer.cleanup_dataset("ds101", []) end)

    assert @redis.command!(["EXISTS", "forklift:data:ds101"]) == 0
  end

  test "cleanup_dataset/2 deletes the stream when no messages have been read for a while and stream length = 0" do
    data = TDG.create_data(dataset_id: "ds102")
    DataBuffer.write(data)
    number_of_empty_reads = Application.get_env(:forklift, :number_of_empty_reads_to_delete, 50)

    0..(number_of_empty_reads + 1)
    |> Enum.each(fn _ -> DataBuffer.cleanup_dataset("ds102", []) end)

    assert @redis.command!(["EXISTS", "forklift:data:ds102"]) == 1
  end

  defp ok({:ok, value}), do: value
end
