defmodule Estuary.MessageHandler do
  use Elsa.Consumer.MessageHandler
  require Logger

  def handle_messages(messages) do
    Logger.debug("Messages #{inspect(messages)} were sent to the eventstream")
    :ack
  end
end
