defmodule Estuary.StartTest do
  use ExUnit.Case
  use Placebo
  use Divo

  @elsa_endpoint Application.get_env(:estuary, :elsa_endpoint)
  @event_stream_topic Application.get_env(:estuary, :event_stream_topic)

  setup do
    allow(Estuary.MessageHandler.handle_messages(any()),
      return: :ack,
      meck_options: [:passthrough]
    )

    :ok
  end

  test "Topic is created when Estuary starts" do
    assert Elsa.Topic.exists?(@elsa_endpoint, @event_stream_topic)
  end

  test "Estuary.Message reads message from eventstream when event stream receives an event" do
    Elsa.produce(@elsa_endpoint, @event_stream_topic, {"key", "value1"})

    Process.sleep(2000)

    assert_called(
      Estuary.MessageHandler.handle_messages(
        [
          %Elsa.Message{
            generation_id: any(),
            key: "key",
            offset: 0,
            partition: 0,
            timestamp: any(),
            topic: @event_stream_topic,
            value: "value1"
          }
        ],
        %{}
      )
    )
  end
end
