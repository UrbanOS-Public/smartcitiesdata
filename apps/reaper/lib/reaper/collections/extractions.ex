defmodule Reaper.Collections.Extractions do
  @moduledoc false
  use Reaper.Collections.BaseDataset, collection: :extractions

  def should_send_data_ingest_start?(%SmartCity.Dataset{technical: %{sourceType: "stream"}} = dataset) do
    get_last_fetched_timestamp!(dataset.id) == nil
  end

  def should_send_data_ingest_start?(_dataset), do: true
end
