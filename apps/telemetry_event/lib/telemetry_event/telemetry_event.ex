defmodule TelemetryEvent do
  @moduledoc false
  alias TelemetryEvent.Helper.TelemetryEventHelper
  alias TelemetryEvent.Helper.AddInitServer

  def config_init_server(child, app_name) do
    AddInitServer.add_metrics_prometheus(child, app_name)
    AddInitServer.add_poller(child)
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
