defmodule Reaper.Collections.Extractions do
  @moduledoc false

  @instance_name Reaper.instance_name()

  use Reaper.Collections.BaseIngestion, instance: @instance_name, collection: :extractions

  # TODO: If there is an asterisk in the second or minute of crontab, do not send data_ingest 
  def should_send_data_ingest_start?(%SmartCity.Ingestion{} = ingestion) do
    get_last_fetched_timestamp!(ingestion.id) == nil
  end

  def should_send_data_ingest_start?(_ingestion), do: true
end
