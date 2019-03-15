defmodule Forklift.MessageWriterTest do
  use ExUnit.Case, async: false
  use Placebo

  alias Forklift.{PersistenceClient, MessageWriter, CacheClient, DeadLetterQueue}

  test "happy path is successful" do
    redis_key_a = "forklift:dataset:KeyA:5"
    redis_key_b = "forklift:dataset:KeyB:6"
    messages_a = create_messages(redis_key_a)
    messages_b = create_messages(redis_key_b)

    allow(CacheClient.read_all_batched_messages(), return: messages_a ++ messages_b)
    expect(CacheClient.delete([redis_key_a, redis_key_a]), return: :ok)
    expect(CacheClient.delete([redis_key_b, redis_key_b]), return: :ok)

    expected_for_id_a = create_presto_expectation(messages_a)
    expected_for_id_b = create_presto_expectation(messages_b)

    expect(PersistenceClient.upload_data("KeyA", expected_for_id_a), return: :ok)
    expect(PersistenceClient.upload_data("KeyB", expected_for_id_b), return: :ok)

    MessageWriter.handle_info(:work, %{})
  end

  test "sends malformed messages to dead letter queue" do
    redis_key = "forklift:dataset:KeyA:5"

    malformed_messages =
      create_messages(redis_key)
      |> Enum.map(fn {key, message} -> {key, String.replace(message, "a", "z")} end)

    allow(CacheClient.read_all_batched_messages(), return: malformed_messages)
    expect(CacheClient.delete(redis_key), return: :ok)

    expect(DeadLetterQueue.enqueue(Enum.at(malformed_messages, 0) |> elem(1)), return: :ok)
    expect(DeadLetterQueue.enqueue(Enum.at(malformed_messages, 1) |> elem(1)), return: :ok)

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
