defmodule Estuary.MessageHandler do
  @moduledoc """
  Estuary.MessageHandler reads events from the event stream and persists them.
  """
  use Elsa.Consumer.MessageHandler
  alias Estuary.DataWriter

  @updated_event_stream "updated_event_stream"

  def handle_messages(messages) do
    messages
    |> Enum.map(fn message ->
      message.value
      |> Jason.decode!()
      |> broadcast_event()
    end)
    |> DataWriter.write()
    |> error_dead_letter()

    :ack
  end

  defp broadcast_event(event) do
    EstuaryWeb.Endpoint.broadcast!(@updated_event_stream, "updated_event_stream", event)
    event
  end

  defp error_dead_letter({:error, event, reason}) do
    DeadLetter.process("Unknown", event, "estuary", reason: reason)
    :error
  end

  defp error_dead_letter(_), do: :ok
end
