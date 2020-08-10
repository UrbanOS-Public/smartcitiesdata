defmodule TelemetryEvent.Helper.AddMetrics do
  @moduledoc false

  def add_metrics_options(metrics_options) do
    [events_handled() | metrics_options]
  end

  defp events_handled() do
    [
      metric_name: "events_handled.count",
      tags: [:app, :author, :dataset_id, :event_type],
      metric_type: :counter
    ]
  end
end
