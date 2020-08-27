defmodule TelemetryEvent.Helper.AddMetrics do
  @moduledoc false

  def add_metrics_options(metrics_options) do
    metrics_options
    |> events_handled()
    |> http_request()
  end

  defp events_handled(metrics_options) do
    [
      [
        metric_name: "events_handled.count",
        tags: [:app, :author, :dataset_id, :event_type],
        metric_type: :counter
      ] | metrics_options]
  end

  defp http_request(metrics_options) do
    case Application.get_env(:telemetry_event, :add_poller) do
      true -> [
        [
          metric_name: "http.request.duration",
          tags: [:app, :controller, :action],
          metric_type: :distribution
        ] | metrics_options]
      _ -> metrics_options
    end
  end
end
