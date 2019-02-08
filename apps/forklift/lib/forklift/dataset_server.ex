defmodule Forklift.DatasetServer do
  use GenServer

  alias Forklift.PrestoClient

  @batch_size 5000

  defmodule State do
    defstruct dataset_id: nil, messages: []

    def set_messages(state, messages) do
      %State{state | messages: messages}
    end
  end

  ##############
  # Client API #
  ##############
  def start_link(dataset_id) do
    GenServer.start_link(__MODULE__, dataset_id, name: dataset_id)
  end

  def ingest_message(pid, message) do
    GenServer.call(pid, {:ingest_message, message})
  end

  #############
  # Callbacks #
  #############
  def init(dataset_id) do
    {:ok, %State{dataset_id: dataset_id}}
  end

  def handle_call(
        {:ingest_message, message},
        _from,
        %State{dataset_id: dataset_id, messages: messages} = state
      ) do
    message_set = [message | messages]

    if length(message_set) >= @batch_size do
      PrestoClient.upload_data(dataset_id, message_set)
      {:reply, :ok, State.set_messages(state, [])}
    else
      {:reply, :ok, State.set_messages(state, message_set), 60_000}
    end
  end

  #####################
  # Private Functions #
  #####################
end
