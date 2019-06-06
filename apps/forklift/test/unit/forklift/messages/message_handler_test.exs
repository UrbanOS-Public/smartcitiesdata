defmodule MessageHandlerTest do
  use ExUnit.Case
  use Placebo

  alias SmartCity.TestDataGenerator, as: TDG
  alias Forklift.Messages.MessageHandler
  alias Forklift.DeadLetterQueue

  @moduletag capture_log: true
  test "malformed messages are sent to dead letter queue" do
    malformed_kaffe_message =
      TDG.create_data(dataset_id: "ds1")
      |> (fn message -> Helper.make_kafka_message(message, "streaming-transformed") end).()
      |> Map.update(:value, "", &String.replace(&1, "a", "z"))

    expect Forklift.handle_batch(any()), return: []
    expect DeadLetterQueue.enqueue(any(), any()), return: :ok
    allow Kaffe.Producer.produce_sync("streaming-persisted", any()), return: :ok

    MessageHandler.handle_messages([malformed_kaffe_message])

    refute_called Kaffe.Producer.produce_sync("streaming-persisted", any())
  end
end
