defmodule Forklift.EventHandler do
  @moduledoc false
  use Brook.Event.Handler

  alias SmartCity.Dataset
  import Forklift
  require Logger

  @reader Application.get_env(:forklift, :data_reader)

  import SmartCity.Event, only: [data_ingest_start: 0, dataset_update: 0, data_ingest_end: 0, data_write_complete: 0]
  import Brook.ViewState

  def handle_event(%Brook.Event{type: data_ingest_start(), data: %Dataset{} = dataset}) do
    with source_type when source_type in ["ingest", "stream"] <- dataset.technical.sourceType,
         init_args <- reader_args(dataset) do
      :ok = @reader.init(init_args)
      Forklift.Datasets.update(dataset)
    else
      _ -> :discard
    end
  end

  def handle_event(%Brook.Event{type: dataset_update(), data: %Dataset{technical: %{sourceType: type}} = dataset})
      when type in ["stream", "ingest"] do
    [table: dataset.technical.systemName, schema: dataset.technical.schema]
    |> Forklift.DataWriter.init()

    :discard
  end

  def handle_event(%Brook.Event{type: data_ingest_end(), data: %Dataset{} = dataset}) do
    with args <- reader_args(dataset),
         :ok <- @reader.terminate(args) do
      Forklift.Datasets.delete(dataset.id)
    else
      _ -> :discard
    end
  end

  def handle_event(%Brook.Event{type: "migration:last_insert_date:start"}) do
    Logger.info("Starting last insert date migration")
    keys = Redix.command!(:redix, ["KEYS", "forklift:last_insert_date:*"])

    keys
    |> Enum.map(fn key -> {key, Redix.command!(:redix, ["GET", key])} end)
    |> Enum.map(fn {key, timestamp} -> {parse_dataset_id(key), timestamp} end)
    |> Enum.each(fn {dataset_id, timestamp} ->
      {:ok, event} = SmartCity.DataWriteComplete.new(%{id: dataset_id, timestamp: timestamp})
      Brook.Event.send(:forklift, data_write_complete(), :forklift, event)
    end)

    keys |> Enum.each(fn key -> Redix.command!(:redix, ["EXPIRE", key, 86430]) end)

    Logger.info("Completed last insert date migration")

    create(:migration, "last_insert_date_migration_completed", true)
  rescue
    error ->
      Logger.error("Failure in last insert date migration" <> error)
  end

  defp parse_dataset_id("forklift:last_insert_date:" <> dataset_id), do: dataset_id

  defp reader_args(dataset) do
    [
      instance: instance_name(),
      endpoints: Application.get_env(:forklift, :elsa_brokers),
      dataset: dataset,
      handler: Forklift.MessageHandler,
      input_topic_prefix: Application.get_env(:forklift, :input_topic_prefix),
      retry_count: Application.get_env(:forklift, :retry_count),
      retry_delay: Application.get_env(:forklift, :retry_initial_delay),
      topic_subscriber_config: Application.get_env(:forklift, :topic_subscriber_config, []),
      handler_init_args: [dataset: dataset]
    ]
  end
end
