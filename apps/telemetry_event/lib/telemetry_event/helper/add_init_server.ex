defmodule TelemetryEvent.Helper.AddInitServer do
  @moduledoc false
  alias TelemetryEvent.Helper.TelemetryEventHelper

  def add_metrics_prometheus(child, app_name) do
    case Application.get_env(:telemetry_event, :init_server) do
      false -> child
      _ -> [{TelemetryMetricsPrometheus, TelemetryEventHelper.metrics_config(app_name)} | child]
    end
  end

  def add_poller(child) do
    case Application.get_env(:telemetry_event, :add_poller) do
      true -> [{:telemetry_poller, measurements: periodic_measurements(), period: 10_000} | child]
      _ -> child
    end
  end

  defp periodic_measurements do
    [
      # A module, function and arguments to be invoked periodically.
      # This function must call :telemetry.execute/3 and a metric must be added above.
      # {MyApp, :count_users, []}
    ]
  end
end
