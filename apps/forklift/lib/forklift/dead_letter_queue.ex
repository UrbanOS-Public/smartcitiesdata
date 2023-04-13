defmodule Forklift.DeadLetterQueue do
  @moduledoc """
  Wrapper for sending messages to the dead letter queue.
  """

  def enqueue(message, options \\ []) do
    enqueue_message(message, options)
  end

  defp enqueue_message(%{id: dataset_id} = message, options) do
    DeadLetter.process(dataset_id, "in message value", message, "forklift", inspect(options))
  end

  defp enqueue_message(message, options) do
    DeadLetter.process("Unknown", "Unknown", message, "forklift", inspect(options))
  end
end
