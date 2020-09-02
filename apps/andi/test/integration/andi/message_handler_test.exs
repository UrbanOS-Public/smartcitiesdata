defmodule Andi.MessageHandlerTest do
  use ExUnit.Case

  import SmartCity.TestHelper, only: [eventually: 1]

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.MessageHandler
  alias Andi.InputSchemas.Datasets

  test "dlq messages are added to the corresponding dataset in postgres" do
    dataset = TDG.create_dataset(%{})
    {:ok, _} = Datasets.update(dataset)

    dlq_message = %{"dataset_id" => dataset.id}
    elsa_messages = [%Elsa.Message{value: Jason.encode!(dlq_message)}]

    MessageHandler.handle_messages(elsa_messages, %{})

    eventually(fn ->
      andi_dataset = Datasets.get(dataset.id)
      assert dlq_message == andi_dataset.dlq_message
    end)
  end
end
