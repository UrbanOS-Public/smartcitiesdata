defmodule Flair.MessageHandler do
  @moduledoc """
  Receives messages from kafka and then process them.
  """
  use Elsa.Consumer.MessageHandler
  alias Flair.Producer

  def handle_messages(message_set) do
    Producer.add_messages(:durations, message_set)

    :ack
  end
end
