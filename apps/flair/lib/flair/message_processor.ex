defmodule Flair.MessageProcessor do
  @moduledoc """
  Receives messages from kafka and then process them.
  """
  use KafkaEx.GenConsumer
  alias Flair.Producer

  def handle_message_set(message_set, state) do
    case Producer.add_messages(:durations, message_set) do
      :ok ->
        {:async_commit, state}

      error ->
        raise "Couldn't add messages: #{inspect(error)}"
    end
  end
end
