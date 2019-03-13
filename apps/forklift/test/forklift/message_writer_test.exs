defmodule Forklift.MessageWriterTest do
  use ExUnit.Case, async: false
  use Placebo

  alias Forklift.{PrestoClient, MessageWriter, RedisClient}

  test "does all the things" do
    id_a = "forklift:dataset:KeyA:5"
    id_b = "forklift:dataset:KeyB:6"

    messages_a =
      Mockaffe.create_messages(:data, :basic, 2)
      |> Enum.map(&Map.put(&1, :dataset_id, id_a))
      |> Enum.map(&Jason.encode!/1)
      |> Enum.map(&{id_a, &1})

    messages_b =
      Mockaffe.create_messages(:data, :basic, 2)
      |> Enum.map(&Map.put(&1, :dataset_id, id_b))
      |> Enum.map(&Jason.encode!/1)
      |> Enum.map(&{id_b, &1})

    messages = messages_a ++ messages_b
    presto_messages = messages |> Enum.map(fn {k, v} -> v end)

    allow(RedisClient.read_all_batched_messages(), return: messages)
    allow(RedisClient.delete(any()), return: :ok)

    m_a =
      messages_a
      |> Enum.map(&elem(&1, 1))
      |> Enum.map(fn x ->
        {:ok, msg} = SCOS.DataMessage.new(x)
        msg
      end)

    m_b =
      messages_b
      |> Enum.map(&elem(&1, 1))
      |> Enum.map(fn x ->
        {:ok, msg} = SCOS.DataMessage.new(x)
        msg
      end)

    expect(PrestoClient.upload_data("KeyA", m_a), return: :ok)
    expect(PrestoClient.upload_data("KeyB", m_b), return: :ok)

    MessageWriter.handle_info(:work, %{})
  end
end
