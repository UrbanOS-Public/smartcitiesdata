defmodule Forklift.MessageHandlerTest do
  use ExUnit.Case
  use Placebo

  alias SmartCity.TestDataGenerator, as: TDG
  alias Forklift.MessageHandler
  alias Forklift.DeadLetterQueue

  @moduletag capture_log: true
  test "malformed messages are sent to dead letter queue" do
    malformed_kafka_message =
      TDG.create_data(dataset_id: "ds1")
      |> (fn message -> Helper.make_kafka_message(message, "streaming-transformed") end).()
      |> Map.update(:value, "", &String.replace(&1, "a", "z"))

    dataset = TDG.create_dataset(%{id: "id", technical: %{systemName: "system__name", schema: []}})

    expect Forklift.handle_batch(any(), dataset), return: []
    expect DeadLetterQueue.enqueue(any(), any()), return: :ok
    allow Elsa.produce_sync(any(), any(), name: any()), return: :ok

    MessageHandler.handle_messages([malformed_kafka_message], %{dataset: dataset})

    refute_called Elsa.produce_sync(any(), any(), name: any())
  end
end
