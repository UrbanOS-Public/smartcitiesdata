defmodule Andi.DatasetCache do
  @moduledoc false
  use GenServer

  require Logger

  alias Andi.Services.DatasetRetrieval

  # Client
  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def put_datasets(datasets) when is_list(datasets) do
    Enum.each(datasets, &put_dataset/1)
  end

  def put_dataset(%SmartCity.Dataset{} = dataset) do
    :ets.insert(__MODULE__, {dataset.id, dataset})
  end

  def put_dataset(invalid_dataset) do
    Logger.warn("Not caching dataset because it is invalid: #{inspect(invalid_dataset)}")
  end

  def get_datasets do
    :ets.match(__MODULE__, {:_, :"$1"}) |> List.flatten()
  end

  # Callbacks
  def init(_) do
    # Warning: Be extremely careful using :public for ETS tables. This can lead to race conditions and all kinds of bad things.
    # In this case Brook is already single threaded so it should be ok.
    pid = :ets.new(__MODULE__, [:set, :public, :named_table])

    DatasetRetrieval.get_all!() |> put_datasets()

    {:ok, pid}
  end

  def handle_call(:reset, _from, _state) do
    :ets.delete(__MODULE__)
    {:ok, pid} = init([])

    {:reply, :ok, pid}
  end
end
