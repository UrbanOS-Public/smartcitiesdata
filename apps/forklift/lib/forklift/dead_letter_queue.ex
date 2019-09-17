defmodule Forklift.DeadLetterQueue do
  @moduledoc """
  Wrapper for sending messages to the dead letter queue.
  """

  def enqueue(message, options \\ []) do
    enqueue_message(message, options)
  end

  defp enqueue_message(%{id: dataset_id} = message, options) do
    Yeet.process_dead_letter(dataset_id, message, "Forklift", options)
  end

  defp enqueue_message(message, options) do
    Yeet.process_dead_letter("Unknown", message, "Forklift", options)
  end
end
