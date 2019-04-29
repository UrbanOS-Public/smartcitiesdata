defmodule Forklift.DeadLetterQueue do
  @moduledoc false
  def enqueue(message, options \\ []) do
    Yeet.process_dead_letter(message, "Forklift", options)
  end
end
