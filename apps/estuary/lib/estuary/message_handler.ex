defmodule Estuary.MessageHandler do
  use Elsa.Consumer.MessageHandler

  def handle_messages(msgs) do
    :acknowledge
  end
end
