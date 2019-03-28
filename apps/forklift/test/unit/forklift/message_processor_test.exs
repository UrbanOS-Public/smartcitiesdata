defmodule MessageProcessorTest do
  use ExUnit.Case
  use Placebo

  alias SmartCity.TestDataGenerator, as: TDG

  alias Forklift.{MessageProcessor, CacheClient, DeadLetterQueue}

  test "data messages are sent to cache client" do
    message = TDG.create_data(dataset_id: "ds1")
    kaffe_message = Helper.make_kafka_message(message, "streaming-transformed")

    expect(
      CacheClient.write(
        kaffe_message.value,
        message.dataset_id,
        kaffe_message.partition,
        kaffe_message.offset
      ),
      return: :ok
    )

    MessageProcessor.handle_messages([kaffe_message])
  end

  @moduletag capture_log: true
  test "malformed messages are sent to dead letter queue" do
    malformed_kaffe_message =
      TDG.create_data(dataset_id: "ds1")
      |> (fn message -> Helper.make_kafka_message(message, "streaming-transformed") end).()
      |> Map.update(:value, "", &String.replace(&1, "a", "z"))

    expect(DeadLetterQueue.enqueue(any()), return: :ok)

    MessageProcessor.handle_messages([malformed_kaffe_message])
  end
end
