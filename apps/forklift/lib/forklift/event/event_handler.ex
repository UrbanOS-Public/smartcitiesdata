defmodule Forklift.Event.EventHandler do
  @moduledoc false
  use Brook.Event.Handler
  alias SmartCity.Dataset
  alias SmartCity.Ingestion
  alias Pipeline.Writer.TableWriter.Helper.PrestigeHelper
  require Logger

  import SmartCity.Event,
    only: [
      data_ingest_start: 0,
      data_extract_start: 0,
      dataset_update: 0,
      data_ingest_end: 0,
      data_write_complete: 0,
      error_dataset_update: 0,
      error_ingestion_update: 0,
      dataset_delete: 0,
      ingestion_delete: 0,
      ingestion_update: 0,
      data_extract_end: 0
    ]

  import Brook.ViewState

  @instance_name Forklift.instance_name()

  def handle_event(%Brook.Event{
        type: data_ingest_start(),
        data: %Ingestion{targetDatasets: dataset_ids} = data,
        author: author
      }) do
    Logger.info("Ingestion: #{data.id}, Datasets: #{dataset_ids} - Received data_ingest_start event from #{author}")

    Enum.each(dataset_ids, fn dataset_id ->
      data_ingest_start()
      |> add_event_count(author, dataset_id)

      dataset = Forklift.Datasets.get!(dataset_id)

      if dataset != nil do
        :ok = Forklift.DataReaderHelper.init(dataset)
      end
    end)

    :discard
  rescue
    error ->
      Logger.error("data_ingest_start failed to process. #{inspect(error)}")
      DeadLetter.process(data.targetDatasets, data.id, data, Atom.to_string(@instance_name), reason: inspect(error))
      :discard
  end

  def handle_event(%Brook.Event{
        type: data_extract_start(),
        data: %Ingestion{targetDatasets: target_dataset_ids} = data,
        author: author
      }) do
    Logger.info("Ingestion: #{data.id} - Received data_extract_start event from #{author}")

    Enum.each(target_dataset_ids, fn target_dataset_id ->
      add_event_count(data_extract_start(), author, target_dataset_id)
      dataset = Brook.get!(@instance_name, :datasets, target_dataset_id)

      if dataset != nil do
        :ok = Forklift.DataReaderHelper.init(dataset)
      else
        Logger.error("Could not find dataset_id: #{target_dataset_id} in ingestion: #{data.id}")
      end
    end)

    :ok
  rescue
    error ->
      Logger.error("data_extract_start failed to process: #{inspect(error)}")
      DeadLetter.process(data.targetDatasets, data.id, data, Atom.to_string(@instance_name), reason: inspect(error))
      :discard
  end

  def handle_event(%Brook.Event{
        type: dataset_update(),
        data: %Dataset{technical: %{sourceType: type}} = data,
        author: author
      })
      when type in ["stream", "ingest"] do
    Logger.info("Dataset: #{data.id} - Received dataset_update event from #{author}")

    dataset_update()
    |> add_event_count(author, data.id)

    Forklift.Datasets.update(data)

    if !PrestigeHelper.table_exists?(data.technical.systemName) do
      init_result =
        Forklift.DataWriter.init(
          table: data.technical.systemName,
          schema: data.technical.schema,
          json_partitions: ["_extraction_start_time", "_ingestion_id"],
          main_partitions: ["_ingestion_id"]
        )

      event_data = create_event_log_data(data.id)

      case init_result do
        :ok -> Brook.Event.send(@instance_name, data_ingest_start(), :forklift, event_data)
        {:error, reason} -> raise reason
      end
    end

    :discard
  rescue
    error ->
      Logger.error("dataset_update failed to process. #{inspect(error)}")
      DeadLetter.process([data.id], nil, data, Atom.to_string(@instance_name), reason: inspect(error))
      Brook.Event.send(@instance_name, error_dataset_update(), :forklift, %{"reason" => error, "dataset" => data})
      :discard
  end

  def handle_event(%Brook.Event{
        type: ingestion_update(),
        data: %Ingestion{} = ingestion,
        author: author
      }) do
    Logger.info("Ingestion: #{ingestion.id} - Received ingestion_update event from #{author}")

    ingestion_update()
    |> add_event_count(author, ingestion.id)

    Forklift.Ingestions.update(ingestion)

    :discard
  rescue
    error ->
      Logger.error("ingestion_update failed to process. #{inspect(error)}")

      DeadLetter.process([ingestion.targetDatasets], ingestion.id, ingestion, Atom.to_string(@instance_name),
        reason: inspect(error)
      )

      :discard
  end

  def handle_event(%Brook.Event{type: data_ingest_end(), data: %Dataset{} = data, author: author}) do
    Logger.info("Datasets: #{data.id} - Received data_ingest_end event from #{author}")

    data_ingest_end()
    |> add_event_count(author, data.id)

    Forklift.DataReaderHelper.terminate(data)
    Forklift.Datasets.delete(data.id)

    :discard
  rescue
    error ->
      Logger.error("data_ingest_end failed to process.")
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
          } = data
      }) do
    Logger.info("Ingestion: #{ingestion_id} - Received data_extract_end event")

    Redix.command!(:redix, ["SET", "#{ingestion_id}" <> "#{extract_start}", msg_target])

    :ok
  rescue
    error ->
      Logger.error("data_extract_end failed to process: #{inspect(error)}")
      DeadLetter.process(dataset_ids, ingestion_id, data, Atom.to_string(@instance_name), reason: inspect(error))
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
    Logger.info("Dataset #{data.id} - Received dataset_delete event from #{author}")

    dataset_delete()
    |> add_event_count(author, data.id)

    case delete_dataset(data) do
      :ok ->
        Logger.info("#{__MODULE__}: Deleted dataset for dataset: #{data.id}")

      {:error, error} ->
        Logger.error("#{__MODULE__}: Failed to delete dataset for dataset: #{data.id}, Reason: #{inspect(error)}")
    end

    :discard
  rescue
    error ->
      Logger.error("dataset_delete failed to process.")
      DeadLetter.process([data.id], nil, data, Atom.to_string(@instance_name), reason: inspect(error))
      :discard
  end

  def handle_event(%Brook.Event{type: ingestion_delete(), data: %SmartCity.Ingestion{} = ingestion, author: author}) do
    Logger.info("Ingestion #{ingestion.id} - Received ingestion_delete event from #{author}")

    ingestion_delete()
    |> add_event_count(author, ingestion.id)

    Forklift.Ingestions.delete(ingestion.id)
    :discard
  rescue
    error ->
      Logger.error("ingestion_delete failed to process.")

      DeadLetter.process([ingestion.targetDatasets], ingestion.id, ingestion, Atom.to_string(@instance_name),
        reason: inspect(error)
      )

      :discard
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

  defp create_event_log_data(dataset_id) do
    %SmartCity.EventLog{
      title: "Table Created",
      timestamp: DateTime.utc_now() |> DateTime.to_string(),
      source: "Forklift",
      description: "Successfully created initial table",
      dataset_id: dataset_id
    }
  end
end
