defmodule Forklift.EventHandler do
  @moduledoc false
  use Brook.Event.Handler

  alias SmartCity.Dataset
  import Forklift
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

  def handle_event(%Brook.Event{type: data_ingest_start(), data: %Dataset{technical: %{sourceType: type}} = dataset})
      when type in ["stream", "ingest"] do
    :ok = Forklift.DataReaderHelper.init(dataset)

    Forklift.Datasets.update(dataset)
  end

  def handle_event(%Brook.Event{type: dataset_update(), data: %Dataset{technical: %{sourceType: type}} = dataset})
      when type in ["stream", "ingest"] do
    [table: dataset.technical.systemName, schema: dataset.technical.schema]
    |> Forklift.DataWriter.init()

    :discard
  rescue
    reason ->
      Brook.Event.send(instance_name(), error_dataset_update(), :forklift, %{"reason" => reason, "dataset" => dataset})
      :discard
  end

  def handle_event(%Brook.Event{type: data_ingest_end(), data: %Dataset{} = dataset}) do
    Forklift.DataReaderHelper.terminate(dataset)
    Forklift.Datasets.delete(dataset.id)
  end

  def handle_event(%Brook.Event{type: "migration:last_insert_date:start"}) do
    Logger.info("Starting last insert date migration")
    keys = Redix.command!(:redix, ["KEYS", "forklift:last_insert_date:*"])

    keys
    |> Enum.map(fn key -> {key, Redix.command!(:redix, ["GET", key])} end)
    |> Enum.map(fn {key, timestamp} -> {parse_dataset_id(key), timestamp} end)
    |> Enum.each(fn {dataset_id, timestamp} ->
      {:ok, event} = SmartCity.DataWriteComplete.new(%{id: dataset_id, timestamp: timestamp})
      Brook.Event.send(instance_name(), data_write_complete(), :forklift, event)
    end)

    thirty_days = 2_592_000
    keys |> Enum.each(fn key -> Redix.command!(:redix, ["EXPIRE", key, thirty_days]) end)

    Logger.info("Completed last insert date migration")

    create(:migration, "last_insert_date_migration_completed", true)
  rescue
    error ->
      Logger.error("Failure in last insert date migration" <> error)
  end

  def handle_event(%Brook.Event{type: dataset_delete(), data: %SmartCity.Dataset{} = dataset}) do
    Logger.debug("#{__MODULE__}: Deleting Datatset: #{dataset.id}")

    case delete_dataset(dataset) do
      :ok ->
        Logger.debug("#{__MODULE__}: Deleted dataset for dataset: #{dataset.id}")

      {:error, error} ->
        Logger.error(
          "#{__MODULE__}: Failed to delete dataset for dataset: #{dataset.id}, Reason: #{
            inspect(error)
          }"
        )
    end
  end

  defp delete_dataset(dataset) do
    Forklift.DataReaderHelper.terminate(dataset)
    Forklift.DataWriter.delete(dataset)
    Forklift.Datasets.delete(dataset.id)
  end

  defp parse_dataset_id("forklift:last_insert_date:" <> dataset_id), do: dataset_id
end
