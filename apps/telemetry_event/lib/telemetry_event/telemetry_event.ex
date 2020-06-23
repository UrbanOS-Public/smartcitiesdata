defmodule TelemetryEvent do
  @moduledoc false
  alias Telemetry.Metrics

  def metrics() do
    metrics_options = Application.get_env(:telemetry_event, :metrics_options)

    [
      Metrics.counter(fetch(metrics_options, :metric_name), tags: fetch(metrics_options, :tags))
    ]
  end

  def add_event_count(options) do
    :telemetry.execute([:events_handled], %{}, %{
      app: fetch(options, :app),
      author: fetch(options, :author),
      dataset_id: Keyword.fetch!(options, :dataset_id),
      event_type: fetch(options, :event_type)
    })
  rescue
    error -> {:error, error}
  end

  defp fetch(options, keyword_name) do
    Keyword.fetch!(options, keyword_name)
    |> fetch_value(keyword_name)
  end

  defp fetch_value(value, keyword_name) when is_nil(value) do
    raise "Keyword :#{keyword_name} cannot be nil"
  end

  defp fetch_value(value, _) when not is_nil(value) do
    value
  end
end
