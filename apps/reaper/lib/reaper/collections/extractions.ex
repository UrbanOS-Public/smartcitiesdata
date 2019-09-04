defmodule Reaper.Collections.Extractions do
  @moduledoc false

  alias Brook.ViewState

  @collection :extractions

  def update_dataset(%SmartCity.Dataset{} = dataset) do
    ViewState.merge(@collection, dataset.id, %{dataset: dataset, started_timestamp: DateTime.utc_now()})
  end

  def update_last_fetched_timestamp(id) do
    ViewState.merge(@collection, id, %{last_fetched_timestamp: DateTime.utc_now()})
  end

  def update_streaming_dataset_status(id) do
    ViewState.merge(@collection, id, %{ingested_once: true})
  end

  def get_dataset!(id) do
    case Brook.get!(@collection, id) do
      nil -> nil
      value -> value.dataset
    end
  end

  def get_last_fetched_timestamp!(id) do
    case Brook.get!(@collection, id) do
      nil -> nil
      value -> value.last_fetched_timestamp
    end
  end

  def should_send_streaming_ingest_start?(id) do
    case Brook.get!(@collection, id) do
      nil -> true
      value -> !Map.has_key?(value, :ingested_once)
    end
  end
end
