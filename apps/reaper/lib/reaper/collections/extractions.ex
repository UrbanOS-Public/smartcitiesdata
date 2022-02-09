defmodule Reaper.Collections.Extractions do
  @moduledoc false

  @instance_name Reaper.instance_name()

  use Reaper.Collections.BaseDataset, instance: @instance_name, collection: :extractions

  # TODO: Talk to TIMOTHY!!!
  def should_send_data_ingest_start?(%SmartCity.Dataset{technical: %{sourceType: "stream"}} = dataset) do
    get_last_fetched_timestamp!(dataset.id) == nil
  end

  def should_send_data_ingest_start?(_dataset), do: true
end
