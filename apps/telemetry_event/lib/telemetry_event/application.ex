defmodule TelemetryEvent.Application do
  @moduledoc false
  use Application

  def start(_something, _else) do
    children =
      [
        {TelemetryMetricsPrometheus, metrics_config()}
      ]
      |> List.flatten()

    Supervisor.start_link(children, strategy: :one_for_one, name: TelemetryEvent.Supervisor)
  end

  def metrics_config() do
    metrics_port = Application.get_env(:telemetry_event, :metrics_port)
    [port: metrics_port, metrics: metric_options()]
  end

  def metric_options() do
    [
      metric_name: "events_handled.count",
      tags: [:app, :author, :dataset_id, :event_type]
    ]
    |> TelemetryEvent.metrics()
  end
end
