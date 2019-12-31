defmodule Estuary.MessageHandler do
  @moduledoc """
  Estuary.MessageHandler reads an event from the event stream and persists it.
  """
  use Elsa.Consumer.MessageHandler
  alias Estuary.Datasets.DatasetSchema
  alias Estuary.DataWriter
  alias Estuary.DeadLetterQueue

  def handle_messages(messages) do
    Enum.map(messages, fn message ->
      message
      |> parse()
      |> error_dead_letter()
    end)
  end

  defp parse(%{author: _, create_ts: _, data: _, type: _} = event) do
    event
    |> DatasetSchema.make_datawriter_payload()
    |> DataWriter.write()
  end

  defp parse(_ = event) do
    {:error, event, "Required field missing"}
  end

  defp error_dead_letter({:error, message, reason} = error_tuple) do
    DeadLetterQueue.enqueue(message, reason: reason)
    error_tuple
  end

  defp error_dead_letter(valid), do: valid
end
