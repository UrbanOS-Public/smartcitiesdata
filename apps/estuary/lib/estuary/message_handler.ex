defmodule Estuary.MessageHandler do
  @moduledoc """
  Estuary.MessageHandler reads an event from the event stream and persists it.
  """
  use Elsa.Consumer.MessageHandler
  require Logger

  def handle_messages(messages) do
    Enum.each(messages, fn message ->
      with {:ok, body} <- message.value |> Jason.decode(),
           %{"author" => author, "create_ts" => create_ts, "data" => data, "type" => type} <- body do
        Estuary.EventTable.insert_event_to_table(body)
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
