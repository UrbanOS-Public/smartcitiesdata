defmodule Reaper.Collections.Extractions do
  @moduledoc false

  alias Brook.ViewState

  @collection :extractions

  def update_dataset(%SmartCity.Dataset{} = dataset) do
    ViewState.merge(@collection, dataset.id, %{dataset: dataset, started_timestamp: NaiveDateTime.utc_now()})
  end

  def update_last_fetched_timestamp(id) do
    ViewState.merge(@collection, id, %{last_fetched_timestamp: NaiveDateTime.utc_now()})
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
end
