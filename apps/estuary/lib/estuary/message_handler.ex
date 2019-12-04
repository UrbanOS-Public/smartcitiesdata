defmodule Estuary.MessageHandler do
  use Elsa.Consumer.MessageHandler
  require Logger

  def handle_messages(messages) do
    IO.inspect(messages, label: "MESSAGESSS!!!!!!!!!!!!!!!!!!!!!!")
    event = messages |> Enum.at(0) |> get_in("value");
    # Todo convert from string to map
    Estuary.EventTable.insert_event(event.author, event.create_ts, event.data, event.type)
    Logger.debug("Messages #{inspect(messages)} were sent to the eventstream")
    :ack
  end
end
