defmodule Pipeline.Writer.TableWriter.Helper.TelemetryEventHelper do
  @moduledoc false

  require Logger

  def add_dataset_record_event_count(table_name, count) do
    [
      table_name: table_name
    ]
    |> TelemetryEvent.add_event_metrics([:dataset_record_total], value: %{count: count})
  rescue
    error ->
      Logger.error("Unable to update the metrics: #{error}")
  end
end
