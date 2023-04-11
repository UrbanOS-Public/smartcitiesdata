defmodule TelemetryEvent do
  @moduledoc false
  alias TelemetryEvent.Helper.TelemetryEventHelper

  def config_init_server(child, app_name) do
    child
    |> add_metrics_prometheus(app_name)
    |> add_poller()
  end

  def add_event_metrics(event_tags_and_values, event_name, measurement \\ []) do
    IO.inspect(TelemetryEventHelper.tags_and_values(event_tags_and_values), label: "telemetry_event: ")
    :telemetry.execute(
      event_name,
      Keyword.get(measurement, :value, %{}),
      TelemetryEventHelper.tags_and_values(event_tags_and_values)
    )
  rescue
    error -> {:error, error}
  end

  defp add_metrics_prometheus(child, app_name) do
    case Application.get_env(:telemetry_event, :init_server) do
      false -> child
      _ -> [{TelemetryMetricsPrometheus, TelemetryEventHelper.metrics_config(app_name)} | child]
    end
  end

  defp add_poller(child) do
    case Application.get_env(:telemetry_event, :add_poller) do
      true -> [{:telemetry_poller, measurements: [], period: :timer.seconds(5)} | child]
      _ -> child
    end
  end
end
