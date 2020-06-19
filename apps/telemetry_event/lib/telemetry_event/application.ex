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
    metrics_port = Application.get_env(:reaper, :telemetry_event)
    Application.get_all_env(:telemetry_event)
    |> Keyword.fetch!(:metrics_port)
    # :application.get_application(__MODULE__)
    # :application.which_application |> List.first
    # __ENV__
    # |> IO.inspect(label: "Portttt")
    IO.inspect(__CALLER__.module, label: "Callerrrrrr")
    [port: metrics_port, metrics: TelemetryEvent.TelemetryHelper.metrics()]
  end
end
