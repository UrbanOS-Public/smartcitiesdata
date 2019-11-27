defmodule Estuary.MessageHandler do
  use Elsa.Consumer.MessageHandler

  def handle_messages(messages) do
    IO.inspect(messages)
    :ack
  end
end
