defmodule Forklift.DatasetServer do
  use GenServer

  defmodule State do
    defstruct messages: []
  end

  ##############
  # Client API #
  ##############
  def start_link(dataset_id) do
    GenServer.start_link(__MODULE__, [], name: dataset_id)
  end

  def ingest_message(pid, message) do
    GenServer.call(pid, {:ingest_message, message})
  end

  #############
  # Callbacks #
  #############
  def init(_args) do
    {:ok, %State{}}
  end

  def handle_call({:ingest_message, _message}, _from, state) do
    {:reply, :ok, state}
  end
  #####################
  # Private Functions #
  #####################
end
