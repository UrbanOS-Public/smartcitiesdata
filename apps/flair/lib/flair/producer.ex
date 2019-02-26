defmodule Flair.Producer do
  use GenStage

  defmodule State do
    defstruct demand: 0, message_set: [], from: []
  end

  ##############
  # Client API #
  ##############
  def start_link(args \\ nil) do
    GenStage.start_link(__MODULE__, args, name: __MODULE__)
  end

  def add_messages(messages) do
    GenStage.call(__MODULE__, {:add, messages}, 5 * 60 * 1_000)
  end

  #############
  # Callbacks #
  #############
  def init(_args) do
    {:producer, %State{}}
  end

  def handle_call({:add, messages}, from, %State{demand: 0} = state) do
    IO.puts("Add messages, no demand")

    {:noreply, [], %State{state | message_set: messages, from: [from | state.from]}}
  end

  def handle_call({:add, messages}, from, %State{demand: demand} = state)
      when length(messages) > demand do
    IO.puts("Add messages, messages > demand")

    {messages_to_dispatch, remaining_messages} = Enum.split(messages, demand)

    new_state = %State{
      state
      | message_set: remaining_messages,
        demand: demand - length(messages_to_dispatch),
        from: [from | state.from]
    }

    {:noreply, messages_to_dispatch, new_state}
  end

  def handle_call({:add, messages}, _from, %State{demand: demand} = state) do
    IO.puts("Add messages default, sync reply")

    new_state = %State{state | demand: demand - length(messages)}

    IO.puts("Replying to caller with #{inspect(new_state)}")
    {:reply, :ok, messages, new_state}
  end

  def handle_demand(demand, %State{message_set: []} = state) when demand > 0 do
    IO.puts("Handle Demand, no messages (#{demand})")

    {:noreply, [], %State{state | demand: demand}}
  end

  def handle_demand(demand, %State{message_set: message_set} = state)
      when demand > 0 and length(message_set) > demand do
    IO.puts("Handle demand, messages > demand (#{demand})")
    {messages_to_dispatch, remaining_messages} = Enum.split(message_set, demand)

    {:noreply, messages_to_dispatch, %State{state | message_set: remaining_messages, demand: 0}}
  end

  def handle_demand(demand, %State{message_set: message_set} = state) when demand > 0 do
    IO.puts("Handle demand, do async reply (#{demand})")

    new_state = %State{state | message_set: [], demand: demand - length(message_set)}

    new_state |> IO.inspect(label: "Replying with current state")

    Enum.each(state.from, fn pid ->
      pid |> IO.inspect(label: "Replying to") |> GenStage.reply(:ok)
    end)

    new_state = %State{new_state | from: []}

    {:noreply, message_set, new_state}
  end
end
