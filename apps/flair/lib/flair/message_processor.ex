defmodule Flair.MessageProcessor do
  use KafkaEx.GenConsumer

  def handle_message_set(message_set, state) do
    Flair.Producer.add_messages(message_set)

    {:async_commit, state}
  end
end
