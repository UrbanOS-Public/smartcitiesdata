defmodule Forklift.Event.Handler do
  @moduledoc false
  use Brook.Event.Handler

  alias SmartCity.Dataset
  alias Forklift.Messages.MessageHandler
  alias Forklift.Datasets.DatasetHandler
  alias Pipeline.Reader.DatasetTopicReader

  import SmartCity.Event, only: [data_ingest_start: 0, dataset_update: 0]

  def handle_event(%Brook.Event{type: data_ingest_start(), data: %Dataset{} = dataset}) do
    with source_type when source_type in ["ingest", "stream"] <- dataset.technical.sourceType,
         reader <- Application.get_env(:forklift, :data_reader),
         reader_init_args <- [dataset: dataset, app: :forklift, handler: MessageHandler] do
      :ok = apply(reader, :init, [reader_init_args])
      {:merge, :datasets_to_process, dataset.id, dataset}
    else
      _ -> :discard
    end
  end

  def handle_event(%Brook.Event{type: dataset_update(), data: %Dataset{} = dataset}) do
    DatasetHandler.create_table_for_dataset(dataset)
    :discard
  end
end
