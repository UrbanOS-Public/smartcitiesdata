defmodule Reaper.ExtractionTask do
  use GenServer, restart: :transient

  def start_link(%{dataset: dataset} = args) do
    GenServer.start_link(__MODULE__, args, max_restarts: 10, max_seconds: 2, name: via_tuple(dataset.id))
  end

  def init(args) do
    {:ok, args, {:continue, :extract_data}}
  end

  def handle_continue(:extract_data, %{dataset: dataset, completion_callback: callback} = state) do
    IO.inspect("Calling process")
    Reaper.DataFeed.process(dataset, callback)
    {:stop, :normal, state}
  end

  def via_tuple(name) do
    {:via, Horde.Registry, {Reaper.Horde.Registry, name}}
  end
end
