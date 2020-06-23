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
    [port: TelemetryEvent.metrics_port(), metrics: TelemetryEvent.metrics()]
  end
end
