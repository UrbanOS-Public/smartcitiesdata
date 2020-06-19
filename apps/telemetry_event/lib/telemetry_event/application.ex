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
    [port: metrics_port, metrics: TelemetryEvent.TelemetryHelper.metrics()]
  end
end
