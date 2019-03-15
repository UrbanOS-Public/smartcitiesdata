defmodule MessageProcessorTest do
  use ExUnit.Case
  use Placebo

  alias Forklift.{MessageAccumulator, MessageProcessor, CacheClient}

  test "data messages are sent to redis client" do
    allow(MessageAccumulator.start_link(any()), return: {:ok, :pid_placeholder})
    allow(MessageAccumulator.send_message(any(), any()), return: :ok)

    message = Mockaffe.create_message(:data, :basic)
    kaffe_message = Helper.make_kafka_message(message, "streaming-transformed")

    expect(
      CacheClient.write(
        kaffe_message.value,
        message.dataset_id,
        kaffe_message.offset
      ),
      return: :ok
    )

    MessageProcessor.handle_messages([kaffe_message])
  end

  # TODO Test that malformed messages are sent to dead letter
end
