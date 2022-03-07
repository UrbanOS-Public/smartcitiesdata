defmodule Forklift.Event.EventHandler do
  @moduledoc false
  use Brook.Event.Handler

  alias SmartCity.Dataset
  alias SmartCity.Ingestion
  require Logger

  import SmartCity.Event,
    only: [
      data_ingest_start: 0,
      dataset_update: 0,
      data_ingest_end: 0,
      data_write_complete: 0,
      error_dataset_update: 0,
      dataset_delete: 0
    ]

  import Brook.ViewState

  @instance_name Forklift.instance_name()

  def handle_event(%Brook.Event{
        type: data_ingest_start(),
        data: %Ingestion{targetDataset: dataset_id} = ingestion,
        author: author
      }) do
    data_ingest_start()
    |> add_event_count(author, dataset_id)
    
    dataset = Forklift.Datasets.get!(dataset_id)
    if dataset != nil do
      :ok = Forklift.DataReaderHelper.init(dataset)
    end
    
  end

  def handle_event(%Brook.Event{
        type: dataset_update(),
        data: %Dataset{technical: %{sourceType: type}} = dataset,
        author: author
      })
      when type in ["stream", "ingest"] do
    dataset_update()
    |> add_event_count(author, dataset.id)
    
    Forklift.Datasets.update(dataset)

    [table: dataset.technical.systemName, schema: dataset.technical.schema]
    |> Forklift.DataWriter.init()

    :discard
  rescue
    reason ->
      Brook.Event.send(@instance_name, error_dataset_update(), :forklift, %{"reason" => reason, "dataset" => dataset})
      :discard
  end

  def handle_event(%Brook.Event{type: data_ingest_end(), data: %Dataset{} = dataset, author: author}) do
    data_ingest_end()
    |> add_event_count(author, dataset.id)

    Forklift.DataReaderHelper.terminate(dataset)
    Forklift.Datasets.delete(dataset.id)
  end

  def handle_event(%Brook.Event{type: "migration:last_insert_date:start", author: author}) do
    "migration:last_insert_date:start"
    |> add_event_count(author, nil)

    Logger.info("Starting last insert date migration")
    keys = Redix.command!(:redix, ["KEYS", "forklift:last_insert_date:*"])

    keys
    |> Enum.map(fn key -> {key, Redix.command!(:redix, ["GET", key])} end)
    |> Enum.map(fn {key, timestamp} -> {parse_dataset_id(key), timestamp} end)
    |> Enum.each(fn {dataset_id, timestamp} ->
      {:ok, event} = SmartCity.DataWriteComplete.new(%{id: dataset_id, timestamp: timestamp})
      Brook.Event.send(@instance_name, data_write_complete(), :forklift, event)
    end)

    thirty_days = 2_592_000
    keys |> Enum.each(fn key -> Redix.command!(:redix, ["EXPIRE", key, thirty_days]) end)

    Logger.info("Completed last insert date migration")

    create(:migration, "last_insert_date_migration_completed", true)
  rescue
    error ->
      Logger.error("Failure in last insert date migration" <> error)
  end

  def handle_event(%Brook.Event{type: dataset_delete(), data: %SmartCity.Dataset{} = dataset, author: author}) do
    Logger.debug("#{__MODULE__}: Deleting Datatset: #{dataset.id}")

    dataset_delete()
    |> add_event_count(author, dataset.id)

    case delete_dataset(dataset) do
      :ok ->
        Logger.debug("#{__MODULE__}: Deleted dataset for dataset: #{dataset.id}")

      {:error, error} ->
        Logger.error("#{__MODULE__}: Failed to delete dataset for dataset: #{dataset.id}, Reason: #{inspect(error)}")
    end
  end

  defp delete_dataset(dataset) do
    Forklift.DataReaderHelper.terminate(dataset)
    Forklift.DataWriter.delete(dataset)
    Forklift.Datasets.delete(dataset.id)
  end

  defp parse_dataset_id("forklift:last_insert_date:" <> dataset_id), do: dataset_id

  defp add_event_count(event_type, author, dataset_id) do
    [
      app: "forklift",
      author: author,
      dataset_id: dataset_id,
      event_type: event_type
    ]
    |> TelemetryEvent.add_event_metrics([:events_handled])
  end
end
