defmodule MessageProcessorTest do
  use ExUnit.Case
  use Placebo

  alias Forklift.MessageAccumulator
  alias Forklift.MessageProcessor

  test "data messages are sent to redis client" do
    allow(MessageAccumulator.start_link(any()), return: {:ok, :pid_placeholder})
    allow(MessageAccumulator.send_message(any(), any()), return: :ok)

    message = Mockaffe.create_message(:data, :basic)
    kaffe_message = Helper.make_kafka_message(message, "streaming-transformed")

    expect(
      Forklift.RedisClient.write(
        kaffe_message.value,
        message.dataset_id,
        kaffe_message.offset
      ),
      return: :ok
    )

    MessageProcessor.handle_messages([kaffe_message])
  end
end
