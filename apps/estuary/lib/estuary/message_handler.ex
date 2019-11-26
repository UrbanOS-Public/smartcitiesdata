defmodule Estuary.MessageHandler do
  use Elsa.Consumer.MessageHandler

  def handle_messages(msgs) do
    IO.puts(msgs)
    :acknowledge
  end
end
