defmodule DatasetServerTest do
  use ExUnit.Case
  use Placebo

  alias Forklift.DatasetServer
  alias Forklift.DatasetServer.State
  alias Forklift.PrestoClient

  test "uploads data when at buffer size" do
    initial_messages = Enum.to_list(1..49)
    new_message = make_message()

    expected_message_set = [new_message | initial_messages]

    expect(PrestoClient.upload_data("cota-whatever", expected_message_set), return: :ok)

    state = %State{
      dataset_id: "cota-whatever",
      messages: initial_messages
    }

    assert {:reply, :ok, %State{messages: []} = state} =
             DatasetServer.handle_call({:ingest_message, new_message}, "from", state)
  end

  test "buffers data when not at buffer size" do
    allow(PrestoClient.upload_data(any(), any()), return: :ok)

    initial_messages = Enum.to_list(1..25)
    new_message = make_message()

    expected_message_set = [new_message | initial_messages]

    state = %State{
      dataset_id: "cota-whatever",
      messages: initial_messages
    }

    assert_called(PrestoClient.upload_data(any(), any()), times(0))

    assert {:reply, :ok, %State{messages: ^expected_message_set} = state} =
             DatasetServer.handle_call({:ingest_message, new_message}, "from", state)
  end

  test "sends messages after no messages "

  def make_message(topic \\ "data-topic") do
    %{
      topic: topic,
      message: "this is a message"
    }
  end
end
