defmodule TelemetryEvent do
  @moduledoc false
  alias TelemetryEvent.Helper.TelemetryEventHelper

  def config_init_server(child, app_name) do
    case Application.get_env(:telemetry_event, :init_server) do
      false -> child
      _ -> [{TelemetryMetricsPrometheus, TelemetryEventHelper.metrics_config(app_name)} | child]
    end
  end

  def add_event_metrics(event_tags_and_values, event_name, measurement \\ []) do
    :telemetry.execute(
      event_name,
      Keyword.get(measurement, :value, %{}),
      TelemetryEventHelper.tags_and_values(event_tags_and_values)
    )
  rescue
    error -> {:error, error}
  end
end
