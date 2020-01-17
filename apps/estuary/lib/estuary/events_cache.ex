defmodule Estuary.EventsCache do
  @moduledoc false
  use GenServer

  require Logger

  import Estuary, only: [instance_name: 0]

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end
  

  def put(invalid_dataset) do
    Logger.warn("Not caching dataset because it is invalid: #{inspect(invalid_dataset)}")
  end


  def get_all do
    :ets.match(__MODULE__, {:_, :"$1"}) |> List.flatten()
  end

  # Callbacks
  def init(_) do
    # Warning: Be extremely careful using :public for ETS tables. This can lead to race conditions and all kinds of bad things.
    # In this case Brook is already single threaded so it should be ok.
    pid = :ets.new(__MODULE__, [:set, :public, :named_table])
    Estuary.Services.EventRetrievalService.get_all() |> put
    # Brook.get_all_values!(instance_name(), :dataset) |> put()
    # Brook.get_all_values!(instance_name(), :ingested_time) |> put()

    {:ok, pid}
  end

  def handle_call(:reset, _from, _state) do
    :ets.delete(__MODULE__)
    {:ok, pid} = init([])

    {:reply, :ok, pid}
  end
end
