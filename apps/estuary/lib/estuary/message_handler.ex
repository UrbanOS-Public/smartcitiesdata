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
    end)
    |> broadcast_events()
    |> DataWriter.write()
    |> error_dead_letter()

    :ack
  end

  defp broadcast_events(events) do
    EstuaryWeb.Endpoint.broadcast!(@updated_event_stream, "updated_event_stream", %{
      events: events
    })

    events
  end

  defp error_dead_letter({:error, event, reason}) do
    DeadLetter.process("Unknown", "Unknown", event, "estuary", reason: inspect(reason))
    :error
  end

  defp error_dead_letter(_), do: :ok
end
