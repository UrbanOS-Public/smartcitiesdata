defmodule Forklift.MessageWriterTest do
  use ExUnit.Case, async: false
  use Placebo

  alias Forklift.{PrestoClient, MessageWriter, RedisClient}

  test "does all the things" do
    redis_key_a = "forklift:dataset:KeyA:5"
    redis_key_b = "forklift:dataset:KeyB:6"
    messages_a = create_messages(redis_key_a)
    messages_b = create_messages(redis_key_b)

    allow(RedisClient.read_all_batched_messages(), return: messages_a ++ messages_b)
    expect(RedisClient.delete([redis_key_a, redis_key_a]), return: :ok)
    expect(RedisClient.delete([redis_key_b, redis_key_b]), return: :ok)

    expected_for_id_a = create_presto_expectation(messages_a)
    expected_for_id_b = create_presto_expectation(messages_b)

    expect(PrestoClient.upload_data("KeyA", expected_for_id_a), return: :ok)
    expect(PrestoClient.upload_data("KeyB", expected_for_id_b), return: :ok)

    MessageWriter.handle_info(:work, %{})
  end

  def create_messages(dataset_id) do
    Mockaffe.create_messages(:data, :basic, 2)
    |> Enum.map(&Map.put(&1, :dataset_id, dataset_id))
    |> Enum.map(&Jason.encode!/1)
    |> Enum.map(&{dataset_id, &1})
  end

  def create_presto_expectation(messages) do
    messages
    |> Enum.map(&elem(&1, 1))
    |> Enum.map(fn x ->
      {:ok, msg} = SCOS.DataMessage.new(x)
      msg
    end)
  end
end
