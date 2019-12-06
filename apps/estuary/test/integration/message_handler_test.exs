defmodule Estuary.MessageHandlerTest do
  use ExUnit.Case
  use Placebo
  use Divo
  import ExUnit.CaptureLog
  require Logger
  import SmartCity.TestHelper, only: [eventually: 1]

  @elsa_endpoint Application.get_env(:estuary, :elsa_endpoint)
  @event_stream_topic Application.get_env(:estuary, :event_stream_topic)

  test "Estuary.MessageHandler reads message from eventstream and logs it if Logger level is set to debug" do
    messages = [
      %Elsa.Message{
        generation_id: 1,
        key: "key",
        offset: 0,
        partition: 0,
        timestamp: "5",
        topic: @event_stream_topic,
        value: ~s({"author": "me", "create_ts": "42", "data": "foo", "type": "bar"})
      }
    ]

    level = Logger.level()
    Logger.configure(level: :debug)

    assert capture_log(fn ->
             Estuary.MessageHandler.handle_messages(messages)
           end) =~ "Messages #{inspect(messages)} were sent to the eventstream"

    Logger.configure([{:level, level}])
  end
end
