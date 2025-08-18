defmodule Flair.MessageHandler do
  @moduledoc """
  Receives messages from kafka and then process them.
  """
  use Elsa.Consumer.MessageHandler
  alias Flair.Producer

  @producer_module Application.compile_env(:flair, :producer_module, Producer)

  def handle_messages(message_set) do
    @producer_module.add_messages(:durations, message_set)

    :ack
  end
end
