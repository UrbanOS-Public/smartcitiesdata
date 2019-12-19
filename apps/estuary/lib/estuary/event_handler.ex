defmodule Estuary.EventHandler do
  @moduledoc false
  use Brook.Event.Handler

  alias SmartCity.Dataset
  alias Estuary.DataWriter

  @reader Application.get_env(:estuary, :topic_reader)

  import SmartCity.Event, only: [data_ingest_start: 0, dataset_update: 0, data_ingest_end: 0]

  def handle_event(%Brook.Event{type: data_ingest_start(), data: %Dataset{} = dataset}) do
    with source_type when source_type in ["ingest", "stream"] <- dataset.technical.sourceType,
         init_args <- reader_args(dataset) do
      :ok = @reader.init(init_args)
      DataWriter.write(dataset)
    else
      _ -> :discard
    end
  end

  defp reader_args(dataset) do
    [
      instance: instance_name(),
      connection: Application.get_env(:estuary, :conection),
      endpoints: Application.get_env(:estuary, :elsa_brokers),
      topic: Application.get_env(:estuary, :event_stream_topic),
      handler: Estuary.MessageHandler,
      handler_init_args: [dataset: dataset],
      topic_subscriber_config: Application.get_env(:estuary, :topic_subscriber_config, []),
      retry_count: Application.get_env(:estuary, :retry_count),
      retry_delay: Application.get_env(:estuary, :retry_initial_delay)
    ]
  end
end
