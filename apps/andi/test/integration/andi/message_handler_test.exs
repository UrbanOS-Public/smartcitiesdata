defmodule Andi.MessageHandlerTest do
  use ExUnit.Case
  use Andi.DataCase

  import SmartCity.TestHelper, only: [eventually: 1]

  @moduletag shared_data_connection: true

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.MessageHandler
  alias Andi.InputSchemas.Datasets

  @endpoints [localhost: 9092]

  test "reading from topic triggers event handler" do
    {:ok, pid} =
      Elsa.Supervisor.start_link(
        connection: :andi_test_reader,
        endpoints: @endpoints,
        consumer: [
          topic: "dead-letters",
          partition: 0,
          begin_offset: :earliest,
          handler: Andi.MessageHandler
        ]
      )

    dataset = TDG.create_dataset(%{})
    {:ok, _} = Datasets.update(dataset)
    dlq_message_value = %{dataset_id: dataset.id} |> Jason.encode!()

    Elsa.produce(@endpoints, "dead-letters", {"key1", dlq_message_value}, partition: 0)

    eventually(fn ->
      andi_dataset = Datasets.get(dataset.id)
      assert andi_dataset.dlq_message != nil
    end)

    Supervisor.stop(pid)
  end

  test "dlq messages are added to the corresponding dataset in postgres" do
    dataset = TDG.create_dataset(%{})
    {:ok, _} = Datasets.update(dataset)

    current_timestamp = DateTime.utc_now()

    current_timestamp_iso =
      current_timestamp
      |> DateTime.truncate(:millisecond)
      |> DateTime.to_iso8601()

    dlq_message = %{"dataset_id" => dataset.id, "timestamp" => current_timestamp_iso}

    elsa_messages = [
      %Elsa.Message{topic: "dead-letters", value: Jason.encode!(dlq_message), timestamp: DateTime.to_unix(current_timestamp, :millisecond)}
    ]

    MessageHandler.handle_messages(elsa_messages, %{})

    eventually(fn ->
      andi_dataset = Datasets.get(dataset.id)
      assert dlq_message == andi_dataset.dlq_message
    end)
  end
end
