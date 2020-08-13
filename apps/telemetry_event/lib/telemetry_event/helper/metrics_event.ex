defmodule TelemetryEvent.Helper.MetricsEvent do
  @moduledoc false
  alias Telemetry.Metrics
  alias TelemetryEvent.Helper.AddMetrics

  def metrics() do
    Application.get_env(:telemetry_event, :metrics_options)
    |> List.wrap()
    |> AddMetrics.add_metrics_options()
    |> Enum.map(fn metrics_option ->
      Keyword.fetch!(metrics_option, :metric_type)
      |> metrics_event(metrics_option)
    end)
  end

  defp metrics_event(:counter, metrics_option) do
    Keyword.fetch!(metrics_option, :metric_name)
    |> Metrics.counter(tags: Keyword.fetch!(metrics_option, :tags))
  end

  defp metrics_event(:sum, metrics_option) do
    Keyword.fetch!(metrics_option, :metric_name)
    |> Metrics.sum(tags: Keyword.fetch!(metrics_option, :tags))
  end

  defp metrics_event(:last_value, metrics_option) do
    Keyword.fetch!(metrics_option, :metric_name)
    |> Metrics.last_value(tags: Keyword.fetch!(metrics_option, :tags))
  end
end
