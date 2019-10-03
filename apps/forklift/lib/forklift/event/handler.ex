defmodule Forklift.Event.Handler do
  @moduledoc false
  use Brook.Event.Handler

  alias SmartCity.Dataset
  alias Forklift.Messages.MessageHandler
  alias Forklift.Datasets.DatasetHandler

  @reader Application.get_env(:forklift, :data_reader)

  import SmartCity.Event, only: [data_ingest_start: 0, dataset_update: 0]

  def handle_event(%Brook.Event{type: data_ingest_start(), data: %Dataset{} = dataset}) do
    with source_type when source_type in ["ingest", "stream"] <- dataset.technical.sourceType,
         init_args <- reader_init_args(dataset) do
      :ok = @reader.init(init_args)
      Forklift.Datasets.update(dataset)
    else
      _ -> :discard
    end
  end

  def handle_event(%Brook.Event{type: dataset_update(), data: %Dataset{} = dataset}) do
    DatasetHandler.create_table_for_dataset(dataset)
    :discard
  end

  defp reader_init_args(dataset) do
    [
      instance: :forklift,
      brokers: Application.get_env(:forklift, :elsa_brokers),
      dataset: dataset,
      handler: MessageHandler,
      input_topic_prefix: Application.get_env(:forklift, :input_topic_prefix),
      retry_count: Application.get_env(:forklift, :retry_count),
      retry_delay: Application.get_env(:forklift, :retry_initial_delay),
      topic_subscriber_config: Application.get_env(:forklift, :topic_subscriber_config, [])
    ]
  end
end
