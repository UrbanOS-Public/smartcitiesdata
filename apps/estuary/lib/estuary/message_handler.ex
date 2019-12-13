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
        do_insert(message, event)
      {_, term} -> process_error(message, term)
    end
  end

  defp do_insert(message, event) do
    case EventTable.insert_event_to_table(event) do
      {:error, _} -> process_error(message, event)
      term -> term
    end
  end

  defp process_error(message, data) do
    Yeet.process_dead_letter("", message, "estuary",
      reason: "could not process because #{inspect(data)}"
    )
  end
end
