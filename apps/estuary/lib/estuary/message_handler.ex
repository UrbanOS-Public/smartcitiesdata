defmodule Estuary.MessageHandler do
  @moduledoc """
  Estuary.MessageHandler reads an event from the event stream and persists it.
  """
  alias Estuary.EventTable
  use Elsa.Consumer.MessageHandler
  require Logger

  def handle_messages(messages) do
    Enum.each(messages, fn message -> process_message(message) end)

    Logger.debug("Messages #{inspect(messages)} were sent to the event stream")
    :ack
  end

  defp process_message(message) do
    case Jason.decode(message.value) do
      {:ok, %{"author" => _, "create_ts" => _, "data" => _, "type" => _} = event} ->
        EventTable.insert_event_to_table(event)

      {:ok, term_without_keys} ->
        Yeet.process_dead_letter("", message, "estuary",
          reason:
            "event #{inspect(term_without_keys)} was decoded but did not have the right keys"
        )

      {:error, %Jason.DecodeError{}} ->
        Yeet.process_dead_letter("", message, "estuary",
          reason: "event's JSON could not be decoded"
        )
    end
  end
end
