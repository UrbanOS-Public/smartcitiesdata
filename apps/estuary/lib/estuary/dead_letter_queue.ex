defmodule Estuary.DeadLetterQueue do
  @moduledoc """
  Wrapper for sending messages to the dead letter queue.
  """

  def enqueue(message, options \\ []) do
    enqueue_message(message, options)
  end

  defp enqueue_message(message, options) do
    DeadLetter.process("Unknown", message, "estuary", options)
  end
end
