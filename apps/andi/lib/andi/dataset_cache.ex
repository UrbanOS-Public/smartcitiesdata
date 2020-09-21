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
    add_dataset_info_total(dataset)

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
    system_name = add_dataset_info_total
    [
      dataset_id: dataset[:id],
      dataset_title: dataset[:business][:dataTitle],
      system_name: "#{dataset[:technical][:orgName]}__#{dataset[:technical][:dataName]}",
      source_type: dataset[:technical][:sourceType],
      org_name: dataset[:technical][:orgName]
    ]
    |> TelemetryEvent.add_event_metrics([:dataset_info], value: %{gauge: 1})
  end

  def add_dataset_info_total(dataset) do
    dataset_info = temp_data()[:data][:result] |> List.first()
    count = dataset_info[:value] |> List.last() |> String.to_integer()
    [
      dataset_id: dataset_info[:metric][:dataset_id],
      dataset_title: dataset_info[:metric][:dataset_title],
      system_name: dataset_info[:metric][:system_name],
      source_type: dataset_info[:metric][:source_type],
      org_name: dataset_info[:metric][:org_name]
    ]
    |> TelemetryEvent.add_event_metrics([:dataset_info_total], value: %{count: count})
  end

  def temp_data() do
    # HTTPoison.get!("http://prometheus.dev.internal.smartcolumbusos.com/api/v1/query?query=dataset_record_total_count{system_name=#{system_name}} * on (system_name) group_left(dataset_id, dataset_title, source_type, org_name) dataset_info_gauge{system_name=#{system_name}}")
    %{
      "status": "success",
      "data": %{
          "resultType": "vector",
          "result": [
              %{
                  "metric": %{
                      "app_kubernetes_io_name": "forklift",
                      "dataset_id": "db1b0434-a6a7-41f3-87c6-6839e213a13e",
                      "dataset_title": "City of Columbus Parking Meter Transactions - 2018",
                      "instance": "10.100.92.58:9002",
                      "job": "kubernetes-service-endpoints",
                      "kubernetes_name": "forklift",
                      "kubernetes_namespace": "streaming-services",
                      "org_name": "ips_group",
                      "source_type": "ingest",
                      "system_name": "ips_group__parking_meter_transactions_2018"
                  },
                  "value": [
                      1600567531.912,
                      "6095888"
                  ]
              }
          ]
      }
  }
  end

end
