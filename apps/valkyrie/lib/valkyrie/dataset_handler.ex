defmodule Valkyrie.DatasetHandler do
  @moduledoc """
  MessageHandler to receive updated datasets and add to the cache
  """
  alias SmartCity.Dataset
  use Brook.Event.Handler
  import SmartCity.Event, only: [data_ingest_start: 0]
  require Logger

  def handle_event(%Brook.Event{
        type: data_ingest_start(),
        data: %Dataset{technical: %{sourceType: source_type}} = dataset
      })
      when source_type in ["ingest", "stream"] do
    Logger.debug("#{__MODULE__}: Handling Datatset: #{dataset.id}")
    Valkyrie.DatasetProcessor.start(dataset)
    {:merge, :datasets, dataset.id, dataset}
  end
end
