defmodule TelemetryEvent do
  @moduledoc false
  alias TelemetryEvent.Helper.TelemetryEventHelper

  def config_init_server(child, app_name) do
    case Application.get_env(:telemetry_event, :init_server) do
      false -> child
      _ -> [{TelemetryMetricsPrometheus, TelemetryEventHelper.metrics_config(app_name)} | child]
    end
  end

  def add_event_count(event_measurements, event_name) do
    :telemetry.execute(event_name, %{}, TelemetryEventHelper.measurements(event_measurements))
  rescue
    error -> {:error, error}
  end
end
