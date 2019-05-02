defmodule MessageProcessorTest do
  use ExUnit.Case
  use Placebo

  alias SmartCity.TestDataGenerator, as: TDG
  alias Forklift.{MessageProcessor, DataBuffer, DeadLetterQueue}

  test "data messages are sent to cache client" do
    data = TDG.create_data(dataset_id: "ds1", payload: %{one: 1})

    kaffe_message = Helper.make_kafka_message(data, "streaming-transformed")

    expect DataBuffer.write(any()), return: {:ok, :does_not_matter}

    assert MessageProcessor.handle_message(kaffe_message) == :ok
  end

  @moduletag capture_log: true
  test "malformed messages are sent to dead letter queue" do
    malformed_kaffe_message =
      TDG.create_data(dataset_id: "ds1")
      |> (fn message -> Helper.make_kafka_message(message, "streaming-transformed") end).()
      |> Map.update(:value, "", &String.replace(&1, "a", "z"))

    expect(DeadLetterQueue.enqueue(any()), return: :ok)

    MessageProcessor.handle_message(malformed_kaffe_message)
  end
end
