defmodule Forklift.DeadLetterQueue do
  @moduledoc false
  def enqueue(message) do
    stack_trace = Process.info(self(), :current_stacktrace)

    message
    |> Yeet.process_dead_letter("Forklift", stacktrace: stack_trace)
  end
end
