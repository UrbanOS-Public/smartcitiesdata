defmodule Pipeline.Writer.TableWriter.Helper.TelemetryEventHelper do
  @moduledoc false

  require Logger

  def add_dataset_record_event_count(count, system_name) when is_integer(count) do
    [
      system_name: system_name
    ]
    |> TelemetryEvent.add_event_metrics([:dataset_record_total], value: %{count: count})
  rescue
    error ->
      Logger.error("Unable to update the metrics: #{error}")
  end

  def add_dataset_record_event_count(_, _), do: :ok
end
