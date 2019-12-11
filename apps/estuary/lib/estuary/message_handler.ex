defmodule Estuary.MessageHandler do
  @moduledoc """
  Estuary.MessageHandler reads an event from the event stream and persists it.
  """
  alias Estuary.EventTable
  use Elsa.Consumer.MessageHandler
  require Logger

  def handle_messages(messages) do
    Enum.each(messages, fn message ->
      with {:ok, body} <- message.value |> Jason.decode(),
           %{"author" => _author, "create_ts" => _create_ts, "data" => _data, "type" => _type} <-
             body do
        EventTable.insert_event_to_table(body)
      else
        {:error, %Jason.DecodeError{}} ->
          Yeet.process_dead_letter("", message, "estuary",
            reason: "event's JSON could not be decoded"
          )

        bad_keys ->
          Yeet.process_dead_letter("", message, "estuary",
            reason: "event #{inspect(bad_keys)} was decoded but did not have the right keys."
          )
      end
    end)

    Logger.debug("Messages #{inspect(messages)} were sent to the eventstream")
    :ack
  end
end
