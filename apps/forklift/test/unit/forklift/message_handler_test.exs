defmodule Forklift.MessageHandlerTest do
  use ExUnit.Case
  
  Code.require_file "../../test_helper.exs", __DIR__

  alias SmartCity.TestDataGenerator, as: TDG
  alias Forklift.MessageHandler
  import SmartCity.TestHelper, only: [eventually: 1]

  @instance_name Forklift.instance_name()

  setup do
    # Setup test environment
    Brook.Test.register(@instance_name)
    
    # Use Test implementation of DeadLetter
    DeadLetter.Carrier.Test.clear()
    
    :ok
  end

  @moduletag capture_log: true
  test "malformed messages are sent to dead letter queue" do
    # Setup test data
    malformed_kafka_message =
      TDG.create_data(dataset_ids: ["ds1"])
      |> (fn message -> Helper.make_kafka_message(message, "streaming-transformed") end).()
      |> Map.update(:value, "", fn value ->
        value
        |> Jason.decode!()
        |> Map.drop(["dataset_ids", "payload"])
        |> Jason.encode!()
      end)

    dataset = TDG.create_dataset(%{id: "ds1", technical: %{systemName: "system__name", schema: []}})

    # Execute the function under test
    MessageHandler.handle_messages([malformed_kafka_message], %{dataset: dataset})

    # Verify expected results
    eventually(fn ->
      {:ok, dlqd_message} = DeadLetter.Carrier.Test.receive()

      assert dlqd_message.app == "forklift"
      assert dlqd_message.dataset_ids == []
      assert dlqd_message.reason =~ "Invalid data message"
    end)
  end
end
