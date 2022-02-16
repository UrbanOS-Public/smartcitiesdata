defmodule Reaper.Collections.Extractions do
  @moduledoc false

  @instance_name Reaper.instance_name()

  use Reaper.Collections.BaseIngestion, instance: @instance_name, collection: :extractions

  def should_send_data_ingest_start?(%SmartCity.Ingestion{} = ingestion) do
    # starting at the beginning of the string (^)
    # match any pattern "* [ANY][ANY]" (\*\s.+)
    # or (|)
    # match any pattern "[ANY] *[ANY]" (.+\s\*)
    if(Regex.match?(~r/^(\*\s.+)|(.+\s\*)/, ingestion.cadence)) do
      get_last_fetched_timestamp!(ingestion.id) == nil
    else
      true
    end
  end
end
