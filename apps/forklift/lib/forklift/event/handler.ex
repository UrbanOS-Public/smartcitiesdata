defmodule Forklift.Event.Handler do
  @moduledoc false
  use Brook.Event.Handler

  require Logger

  alias SmartCity.Dataset
  alias Forklift.Datasets.{DatasetHandler, DatasetSchema}
  import SmartCity.Event, only: [data_ingest_start: 0, dataset_update: 0]

  def handle_event(%Brook.Event{type: data_ingest_start(), data: %Dataset{} = dataset}) do
    with schema = %DatasetSchema{} <- DatasetSchema.from_dataset(dataset),
         {:ok, _} <- DatasetHandler.start_dataset_ingest(schema) do
      {:merge, :datasets_to_process, schema.id, schema}
    else
      _ -> :discard
    end
  end

  def handle_event(%Brook.Event{type: dataset_update(), data: %Dataset{} = dataset}) do
    DatasetHandler.create_table_for_dataset(dataset)

    :discard
  end
end
