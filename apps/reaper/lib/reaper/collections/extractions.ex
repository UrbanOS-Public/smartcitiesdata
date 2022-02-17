defmodule Reaper.Collections.Extractions do
  @moduledoc false

  @instance_name Reaper.instance_name()

  use Reaper.Collections.BaseIngestion, instance: @instance_name, collection: :extractions

  # determine if an ingestion's dataset's sourceType would be streaming
  # by looking for an asterisk in the seconds or minutes cadence field using crontab format
  def is_streaming_source_type?(cadence) do
    # starting at the beginning of the string (^)
    # match any valid crontab character (digit, ',', '-', '/') EXCEPT *:  [\d,-\/]+
    # followed by any number of spaces (at least one):  \s+
    # followed by any valid crontab character (digit, ',', '-', '/') EXCEPT *:  [\d,-\/]+
    # followed by any number of spaces \s
    # This pattern matches the inverse of what we want, so flip it:  !Regex.match
    !Regex.match?(~r/^[\d,-\/]+\s+[\d,-\/]+\s+/, cadence)
  end

  def should_send_data_ingest_start?(%SmartCity.Ingestion{} = ingestion) do
    if(is_streaming_source_type?(ingestion.cadence)) do
      get_last_fetched_timestamp!(ingestion.id) == nil
    else
      true
    end
  end
end
