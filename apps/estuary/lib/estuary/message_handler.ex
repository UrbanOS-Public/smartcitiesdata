defmodule Estuary.MessageHandler do
  use Elsa.Consumer.MessageHandler

  def handle_messages(_messages) do
    :acknowledge
  end
end
