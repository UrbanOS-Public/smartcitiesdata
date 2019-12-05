defmodule Estuary.MessageHandler do
  use Elsa.Consumer.MessageHandler
  require Logger

  def handle_messages(messages) do
    IO.inspect(messages)
    Enum.each(messages, fn message ->
      event = message.value |> Jason.decode!()
      Estuary.EventTable.insert_event(Map.fetch!(event, "author"), Map.fetch!(event, "create_ts"), Map.fetch!(event, "data"), Map.fetch!(event, "type"))
    end)
    Logger.debug("Messages #{inspect(messages)} were sent to the eventstream")
    :ack
  end
end
