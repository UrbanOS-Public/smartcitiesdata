require Logger

defmodule Flair.Producer do
  @moduledoc """
  Producer receives messages from kafka and then passes them to the flow as they are demanded.
  """

  use GenStage

  @message_timeout Application.get_env(:flair, :message_timeout, 50)

  defmodule State do
    @moduledoc """
    The producer's state: namely it's backlog of messages and the demand requested.
    """
    defstruct demand: 0, message_set: [], from: []
  end

  def start_link(name, args \\ nil) do
    GenStage.start_link(__MODULE__, args, name: name)
  end

  def add_messages(name, messages) do
    GenStage.call(name, {:add, messages}, @message_timeout)
  end

  def init(_args) do
    Flair.PrestoClient.get_create_timing_table_statement()
    |> Flair.PrestoClient.execute()

    Flair.PrestoClient.get_create_quality_table_statement()
    |> Flair.PrestoClient.execute()

    {:producer, %State{}}
  end

  def handle_call({:add, messages}, from, %State{demand: 0} = state) do
    {:noreply, [], %State{state | message_set: messages, from: [from | state.from]}}
  end

  def handle_call({:add, messages}, from, %State{demand: demand} = state)
      when length(messages) > demand do
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
    new_state = %State{state | demand: demand - length(messages)}

    {:reply, :ok, messages, new_state}
  end

  def handle_demand(demand, %State{message_set: []} = state) when demand > 0 do
    {:noreply, [], %State{state | demand: demand + state.demand}}
  end

  def handle_demand(demand, %State{message_set: message_set, demand: state_demand} = state)
      when demand > 0 and length(message_set) > demand + state_demand do
    {messages_to_dispatch, remaining_messages} = Enum.split(message_set, demand)

    {:noreply, messages_to_dispatch,
     %State{
       state
       | message_set: remaining_messages,
         demand: max(0, state_demand - demand)
     }}
  end

  def handle_demand(demand, %State{message_set: message_set} = state) when demand > 0 do
    new_state = %State{
      state
      | message_set: [],
        demand: state.demand + demand - length(message_set)
    }

    Enum.each(state.from, fn pid ->
      GenStage.reply(pid, :ok)
    end)

    new_state = %State{new_state | from: []}

    {:noreply, message_set, new_state}
  end
end
