defmodule Estuary.MessageHandler do
  use Elsa.Consumer.MessageHandler
  require Logger

  def handle_messages(messages) do
    IO.inspect(messages, label: "MESSAGESSS!!!!!!!!!!!!!!!!!!!!!!")
    Logger.debug("Messages #{inspect(messages)} were sent to the eventstream")
    :ack
  end
end
