defmodule TelemetryEvent.Helper.MetricsEvent do
  @moduledoc false
  import Telemetry.Metrics
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
    |> counter(tags: Keyword.fetch!(metrics_option, :tags))
  end

  defp metrics_event(:sum, metrics_option) do
    Keyword.fetch!(metrics_option, :metric_name)
    |> sum(tags: Keyword.fetch!(metrics_option, :tags))
  end

  defp metrics_event(:last_value, metrics_option) do
    Keyword.fetch!(metrics_option, :metric_name)
    |> last_value(tags: Keyword.fetch!(metrics_option, :tags))
  end

  defp metrics_event(:distribution, metrics_option) do
    Keyword.fetch!(metrics_option, :metric_name)
    |> distribution(
      event_name: [:phoenix, :endpoint, :stop],
      tags: Keyword.fetch!(metrics_option, :tags),
      tag_values: Keyword.fetch!(metrics_option, :tag_values),
      unit: Keyword.fetch!(metrics_option, :unit),
      reporter_options: Keyword.fetch!(metrics_option, :reporter_options)
    )
  end
end
