defmodule Forklift.DataBufferTest do
  use ExUnit.Case
  use Placebo

  alias SmartCity.TestDataGenerator, as: TDG

  alias Forklift.DataBuffer

  test "write/1 should return an ok tuple on success" do
    allow Redix.command(any(), any()), return: {:ok, :ok}
    data = TDG.create_data(dataset_id: "1")

    assert {:ok, :ok} = DataBuffer.write(data)
  end

  test "write/1 should return error tuple on failed write to redis" do
    allow Redix.command(any(), any()), return: {:error, "Reason Something"}
    data = TDG.create_data(dataset_id: "1")

    assert {:error, "Reason Something"} == DataBuffer.write(data)
  end

  test "write/1 should return error tuple when message fails json encoding" do
    allow Jason.encode(any()), return: {:error, "Json failure"}
    data = TDG.create_data(dataset_id: "1")

    assert {:error, "Json failure"} == DataBuffer.write(data)
  end

  test "get_pending_datasets/0 shoud return empty list when redix returns an error" do
    allow Redix.command(any(), any()), return: {:error, "Failure"}

    assert [] == DataBuffer.get_pending_datasets()
  end

  test "get_pending_data/0 should return empty list when redix returns an error" do
    allow Redix.command(any(), any()), return: {:error, "Failure"}

    assert [] == DataBuffer.get_pending_data("ds1")
  end

  test "get_pending_data marks complete and sends to dead letter when message is not valid" do
    data = TDG.create_data(dataset_id: "ds1", payload: %{one: 1})

    allow Redix.command(:redix, ["XGROUP" | any()]), return: :ok

    allow Redix.command(:redix, ["XREADGROUP" | any()]),
      seq: [
        {:ok, to_xread_result("ds1", [{"k1", "Jerks"}])},
        {:ok, to_xread_result("ds1", [{"k2", Jason.encode!(data)}])}
      ]

    allow Redix.command(:redix, any()), return: :ok
    allow Redix.pipeline(:redix, any()), return: :ok
    allow Forklift.DeadLetterQueue.enqueue(any()), return: :ok

    results = DataBuffer.get_pending_data("ds1")

    assert results == [%{key: "k2", data: data}]

    assert_called Redix.pipeline(:redix, [
                    ["XACK", "forklift:data:ds1", "forklift", "k1"],
                    ["XDEL", "forklift:data:ds1", "k1"]
                  ])

    assert_called Forklift.DeadLetterQueue.enqueue("Jerks")
  end

  test "mark_complete/2 returns error tuple when redix returns an error" do
    allow Redix.pipeline(any(), any()), return: {:error, "Failure"}

    assert {:error, "Failure"} == DataBuffer.mark_complete("key", [%{key: "id"}])
  end

  defp to_xread_result(dataset_id, messages) do
    entries = Enum.map(messages, fn {k, m} -> [k, ["message", m]] end)
    [["forklift:data:#{dataset_id}", entries]]
  end
end
