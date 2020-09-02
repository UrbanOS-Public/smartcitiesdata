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
      true -> [{:telemetry_poller, measurements: [], period: :timer.seconds(5)} | child]
      _ -> child
    end
  end
end
