defmodule Andi.DatasetCache do
  @moduledoc false
  use GenServer

  require Logger

  import Andi, only: [instance_name: 0]

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def put(datasets) when is_list(datasets) do
    Enum.each(datasets, &put/1)
  end

  def put(%SmartCity.Dataset{} = dataset) do
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

  defp get(id) do
    case :ets.match_object(__MODULE__, {id, :"$1"}) do
      [{_key, value} | _t] -> value
      _ -> %{}
    end
  end

  def get_all do
    :ets.match(__MODULE__, {:_, :"$1"}) |> List.flatten()
  end

  # Callbacks
  def init(_) do
    # Warning: Be extremely careful using :public for ETS tables. This can lead to race conditions and all kinds of bad things.
    # In this case Brook is already single threaded so it should be ok.
    pid = :ets.new(__MODULE__, [:set, :public, :named_table])

    Brook.get_all_values!(instance_name(), :dataset) |> put()
    Brook.get_all_values!(instance_name(), :ingested_time) |> put()

    {:ok, pid}
  end

  def handle_call(:reset, _from, _state) do
    :ets.delete(__MODULE__)
    {:ok, pid} = init([])

    {:reply, :ok, pid}
  end
end
