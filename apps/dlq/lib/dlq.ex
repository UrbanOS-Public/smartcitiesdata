defmodule Dlq.Behaviour do
  @moduledoc """
  Defines behaviour of `Dlq` to make testing `Dlq` usage easier.
  """
  @callback write([DeadLetter.t()]) :: :ok
end

defmodule Dlq do
  @moduledoc """
  Used to write `DeadLetter` messages to a dead-letter-queue.
  """
  @behaviour Dlq.Behaviour

  @impl true
  def write(dead_letters) do
    GenServer.cast(Dlq.Server, {:write, dead_letters})
  end
end
