defmodule Reaper.Collections.Extractions do
  @moduledoc false

  def update_dataset(%SmartCity.Dataset{} = dataset) do
    {:merge, name(), dataset.id, %{dataset: dataset}}
  end

  def update_last_fetched_timestamp(id) do
    # {:merge, name(), id, %{last_fetched_timestamp: NaiveDateTime.utc_now()}}
    Brook.merge(name(), id, %{last_fetched_timestamp: NaiveDateTime.utc_now()})
  end

  def get_dataset!(id) do
    case Brook.get!(name(), id) do
      nil -> nil
      value -> value.dataset
    end
  end

  def get_last_fetched_timestamp!(id) do
    case Brook.get!(name(), id) do
      nil -> nil
      value -> value.last_fetched_timestamp
    end
  end

  defp name() do
    :extractions
  end

end
