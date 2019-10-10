defmodule Forklift.EventHandler do
  @moduledoc false
  use Brook.Event.Handler

  alias SmartCity.Dataset
  alias Forklift.MessageHandler
  import Forklift

  @reader Application.get_env(:forklift, :data_reader)

  import SmartCity.Event, only: [data_ingest_start: 0, dataset_update: 0, data_ingest_end: 0]

  def handle_event(%Brook.Event{type: data_ingest_start(), data: %Dataset{} = dataset}) do
    with source_type when source_type in ["ingest", "stream"] <- dataset.technical.sourceType,
         init_args <- reader_args(dataset) do
      :ok = @reader.init(init_args)
      Forklift.Datasets.update(dataset)
    else
      _ -> :discard
    end
  end

  def handle_event(%Brook.Event{type: dataset_update(), data: %Dataset{} = dataset}) do
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

  defp reader_args(dataset) do
    [
      instance: instance_name(),
      endpoints: Application.get_env(:forklift, :elsa_brokers),
      dataset: dataset,
      handler: MessageHandler,
      input_topic_prefix: Application.get_env(:forklift, :input_topic_prefix),
      retry_count: Application.get_env(:forklift, :retry_count),
      retry_delay: Application.get_env(:forklift, :retry_initial_delay),
      topic_subscriber_config: Application.get_env(:forklift, :topic_subscriber_config, [])
    ]
  end
end
