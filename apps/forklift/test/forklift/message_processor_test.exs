defmodule MessageProcessorTest do
  use ExUnit.Case
  use Placebo

  alias Forklift.{MessageProcessor, CacheClient}

  test "data messages are sent to cache client" do
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


end
