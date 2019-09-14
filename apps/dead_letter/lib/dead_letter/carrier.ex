defmodule DeadLetter.Carrier do
  @moduledoc """
  Defines the behaviour that clients must implement
  in order to properly dispatch dead letter messages
  to the waiting message queue service.
  """

  @doc """
  Start a DeadLetter carrier and link to the current process.
  """
  @callback start_link(term()) :: GenServer.on_start()

  @doc """
  Return a child specification for the DeadLetter carrier for
  inclusion in an application supervision tree.
  """
  @callback child_spec(term()) :: Supervisor.child_spec()

  @doc """
  Send the desired message to the message queue processing
  dead letters for the system.
  """
  @callback send(term()) :: :ok | {:error, term()}
end

defmodule DeadLetter.Carrier.Default do
  @moduledoc """
  Default implementation of the `DeadLetter.Carrier` behaviour.
  Simply stores the message in an internal queue via the Erlang
  `:queue` module with a configurable cap.

  Ideal for testing or very small systems.
  """

  use GenServer
  @behaviour DeadLetter.Carrier
  @default_size 2_000
  @name :dead_letter_carrier

  @doc """
  Start the default carrier and link to the calling process.
  """
  @impl DeadLetter.Carrier
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc """
  Initialize the default driver and setup the queue.
  """
  @impl GenServer
  def init(opts) do
    size = Keyword.get(opts, :size, @default_size)
    {:ok, %{size: size, queue: :queue.new()}}
  end

  @doc """
  Add processed message to the end queue.
  """
  @impl DeadLetter.Carrier
  def send(message) do
    GenServer.cast(@name, {:send, message})

    :ok
  end

  @doc """
  Remove the first processed message from the front of the queue.
  """
  def receive() do
    {:ok, GenServer.call(@name, :receive)}
  end

  @impl GenServer
  def handle_cast({:send, message}, state) do
    new_queue = :queue.in(message, state.queue)

    {:noreply, %{state | queue: ensure_queue_size(new_queue, state.size)}}
  end

  @impl GenServer
  def handle_call(:receive, _from, state) do
    {value, new_queue} =
      case :queue.out(state.queue) do
        {{:value, head}, queue} -> {head, queue}
        {:empty, queue} -> {:empty, queue}
      end

    {:reply, value, %{state | queue: new_queue}}
  end

  defp ensure_queue_size(queue, size) do
    case :queue.len(queue) > size do
      true ->
        {_value, new_queue} = :queue.out(queue)
        new_queue

      false ->
        queue
    end
  end
end
