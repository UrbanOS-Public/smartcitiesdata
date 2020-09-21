defmodule Andi.DatasetCache do
  @moduledoc false
  use GenServer

  require Logger

  alias Andi.Services.DatasetStore

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def put(datasets) when is_list(datasets) do
    Enum.each(datasets, &put/1)
  end

  def put(%SmartCity.Dataset{} = dataset) do
    add_dataset_info(dataset)

    updated =
      dataset.id
      |> get()
      |> Map.merge(%{"id" => dataset.id, "dataset" => dataset})

    :ets.insert(__MODULE__, {dataset.id, updated})
  end

  def put(%{"id" => id, "ingested_time" => time_stamp}) do
    updated =
      id
      |> get()
      |> Map.merge(%{"id" => id, "ingested_time" => time_stamp})

    :ets.insert(__MODULE__, {id, updated})
  end

  def put(invalid_dataset) do
    Logger.warn("Not caching dataset because it is invalid: #{inspect(invalid_dataset)}")
  end

  def get(id) do
    case :ets.match_object(__MODULE__, {id, :"$1"}) do
      [{_key, value} | _t] -> value
      _ -> %{}
    end
  end

  def get_all do
    :ets.match(__MODULE__, {:_, :"$1"}) |> List.flatten()
  end

  def delete(id) do
    :ets.match_delete(__MODULE__, {id, :"$1"})
  end

  # Callbacks
  def init(_) do
    # Warning: Be extremely careful using :public for ETS tables. This can lead to race conditions and all kinds of bad things.
    # In this case Brook is already single threaded so it should be ok.
    pid = :ets.new(__MODULE__, [:set, :public, :named_table])

    DatasetStore.get_all!() |> put()
    DatasetStore.get_all_ingested_time!() |> put()

    {:ok, pid}
  end

  def handle_call(:reset, _from, _state) do
    :ets.delete(__MODULE__)
    {:ok, pid} = init([])

    {:reply, :ok, pid}
  end

  def add_dataset_info(dataset) do
    [
      dataset_id: dataset[:id],
      dataset_title: dataset[:business][:dataTitle],
      system_name: dataset[:technical][:systemName],
      source_type: dataset[:technical][:sourceType],
      org_name: dataset[:technical][:orgName]
    ]
    |> TelemetryEvent.add_event_metrics([:dataset_info], value: %{gauge: 1})
  end
end
