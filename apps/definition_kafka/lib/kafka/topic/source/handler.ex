defmodule Kafka.Topic.Source.Handler do
  @moduledoc false
  use Elsa.Consumer.MessageHandler

  def handle_messages(messages, context) do
    messages
    |> Enum.map(fn msg ->
      %Source.Message{original: msg, value: msg.value}
    end)
    |> Source.Handler.inject_messages(context)

    {:ack, context}
  end
end
