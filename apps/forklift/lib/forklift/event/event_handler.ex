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
      dataset_delete: 0,
      data_extract_end: 0
    ]

  import Brook.ViewState

  @instance_name Forklift.instance_name()

  def handle_event(%Brook.Event{
        type: data_ingest_start(),
        data: %Ingestion{targetDatasets: dataset_ids} = data,
        author: author
      }) do
    Enum.each(dataset_ids, fn dataset_id ->
      data_ingest_start()
      |> add_event_count(author, dataset_id)

      dataset = Forklift.Datasets.get!(dataset_id)

      if dataset != nil do
        :ok = Forklift.DataReaderHelper.init(dataset)
      end
    end)

    :ok
  rescue
    error ->
      Logger.error("data_ingest_start failed to process. #{inspect(error)}")

      DeadLetter.process(data.targetDatasets, data.id, data, Atom.to_string(@instance_name), reason: inspect(error))

      :discard
  end

  def handle_event(%Brook.Event{
        type: dataset_update(),
        data: %Dataset{technical: %{sourceType: type}} = data,
        author: author
      })
      when type in ["stream", "ingest"] do
    dataset_update()
    |> add_event_count(author, data.id)

    Forklift.Datasets.update(data)

    [
      table: data.technical.systemName,
      schema: data.technical.schema,
      json_partitions: ["_extraction_start_time", "_ingestion_id"],
      main_partitions: ["_ingestion_id"]
    ]
    |> Forklift.DataWriter.init()

    :discard
  rescue
    error ->
      Logger.error("dataset_update failed to process. #{inspect(error)}")
      DeadLetter.process([data.id], nil, data, Atom.to_string(@instance_name), reason: inspect(error))
      Brook.Event.send(@instance_name, error_dataset_update(), :forklift, %{"reason" => error, "dataset" => data})
      :discard
  end

  def handle_event(%Brook.Event{type: data_ingest_end(), data: %Dataset{} = data, author: author}) do
    data_ingest_end()
    |> add_event_count(author, data.id)

    Forklift.DataReaderHelper.terminate(data)
    Forklift.Datasets.delete(data.id)

    :ok
  rescue
    error ->
      Logger.error("data_ingest_end failed to process.")
      DeadLetter.process([data.id], nil, data, Atom.to_string(@instance_name), reason: inspect(error))
      :discard
  end

  def handle_event(%Brook.Event{type: "migration:last_insert_date:start", author: author} = event) do
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
      Logger.error("migration:last_insert_date:start failed to process.")
      DeadLetter.process([], nil, event, Atom.to_string(@instance_name), reason: inspect(error))
      :discard
  end

  def handle_event(%Brook.Event{type: dataset_delete(), data: %SmartCity.Dataset{} = data, author: author}) do
    Logger.debug("#{__MODULE__}: Deleting Dataset: #{data.id}")

    IO.inspect("Real Delete 1", label: "RYAN - DS DELETE")
    dataset_delete()
    |> IO.inspect(label: "RYAN - Piped")
    |> add_event_count(author, data.id)

    case delete_dataset(data) do
      :ok ->
        IO.inspect("Real Delete 2", label: "RYAN - DS DELETE")
        Logger.debug("#{__MODULE__}: Deleted dataset for dataset: #{data.id}")
        :ok

      {:error, error} ->
        IO.inspect("Real Delete 3", label: "RYAN - DS DELETE")
        Logger.error("#{__MODULE__}: Failed to delete dataset for dataset: #{data.id}, Reason: #{inspect(error)}")
        :discard
    end
  rescue
    error ->
      IO.inspect("Real Delete 4", label: "RYAN - DS DELETE")
      Logger.error("dataset_delete failed to process.")
      DeadLetter.process([data.id], nil, data, Atom.to_string(@instance_name), reason: inspect(error))
      :discard
  end

  def handle_event(%Brook.Event{
        type: data_extract_end(),
        data:
          %{
            "dataset_ids" => dataset_ids,
            "extract_start_unix" => extract_start,
            "ingestion_id" => ingestion_id,
            "msgs_extracted" => msg_target
          } = data,
        author: author
      }) do
    Enum.each(dataset_ids, fn dataset_id ->
      data_extract_end() |> add_event_count(author, dataset_id)

      dataset = Forklift.Datasets.get!(dataset_id)

      ingestion_status = Forklift.IngestionProgress.store_target(dataset, msg_target, ingestion_id, extract_start)

      if ingestion_status == :ingestion_complete do
        Forklift.Jobs.DataMigration.compact(dataset, ingestion_id, extract_start)
      end
    end)


    :ok
  rescue
    error ->
      Logger.error("data_extract_end failed to process.")
      DeadLetter.process(dataset_ids, ingestion_id, data, Atom.to_string(@instance_name), reason: inspect(error))
      :discard
  end

  defp delete_dataset(dataset) do
    IO.inspect("Inner Real Delete 1", label: "RYAN - DS DELETE")
    Forklift.DataReaderHelper.terminate(dataset)
    IO.inspect("Inner Real Delete 2", label: "RYAN - DS DELETE")
    Forklift.DataWriter.delete(dataset)
    IO.inspect("Inner Real Delete 3", label: "RYAN - DS DELETE")
    Forklift.Datasets.delete(dataset.id)
    IO.inspect("Inner Real Delete 4", label: "RYAN - DS DELETE")
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
