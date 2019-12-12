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
    message.value
    |> Jason.decode
    |> process(message)
  end

  defp process({:ok, %{"author" => _, "create_ts" => _, "data" => _, "type" => _} = event}, _message) do
    case EventTable.insert_event_to_table(event) do
      {:error, %Prestige.Error{name: error}} -> Yeet.process_dead_letter("", event, "estuary",
        reason:
          "event #{inspect(event)} had #{error} and could not be inserted")
      term -> IO.inspect(term)
    end
  end

  defp process({:ok, term_without_keys}, message) do
    Yeet.process_dead_letter("", message, "estuary",
      reason:
        "event #{inspect(term_without_keys)} was decoded but did not have the right keys"
    )
  end

  defp process({:error, %Jason.DecodeError{}}, message) do
    Yeet.process_dead_letter("", message, "estuary",
      reason: "event's JSON could not be decoded"
    )
  end
end
