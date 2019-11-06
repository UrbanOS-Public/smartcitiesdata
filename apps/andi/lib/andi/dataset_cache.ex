defmodule Andi.DatasetCache do
  use GenServer

  alias Andi.Services.DatasetRetrieval

  # Client
  def start_link(_) do
    GenServer.start_link(__MODULE__, [])
  end

  def put_datasets(datasets) when is_list(datasets) do
    Enum.each(datasets, &put_dataset/1)
  end

  def put_dataset(%SmartCity.Dataset{} = dataset) do
    :ets.insert(__MODULE__, {dataset.id, dataset})
  end

  def get_datasets do
    :ets.match(__MODULE__, {:_, :"$1"}) |> List.flatten()
  end

  # Callbacks
  def init(_) do
    pid = :ets.new(__MODULE__, [:set, :public, :named_table])

    DatasetRetrieval.get_all!() |> put_datasets()

    {:ok, pid}
  end
end
