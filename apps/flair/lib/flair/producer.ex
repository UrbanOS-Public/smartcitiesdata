defmodule Flair.Producer do
  @moduledoc """
  Producer receives messages from kafka and then passes them to the flow as they are demanded.
  """
  require Logger
  use GenStage

  @message_timeout Application.get_env(:flair, :message_timeout, 5 * 60 * 1_000)

  @type kafka_message :: %{
          key: String.t(),
          value: String.t()
        }

  defmodule State do
    @moduledoc false
    defstruct demand: 0, message_set: [], from: []
  end

  ################
  ## Client API ##
  ################
  def start_link(name, args \\ nil) do
    GenStage.start_link(__MODULE__, args, name: name)
  end

  @spec add_messages(GenStage.stage(), list(kafka_message())) :: term()
  def add_messages(name, messages) do
    GenStage.call(name, {:add, messages}, @message_timeout)
  end

  ###############
  ## Callbacks ##
  ###############
  def init(_args) do
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
