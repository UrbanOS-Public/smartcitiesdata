defmodule TelemetryEvent.Helper.AddMetrics do
  @moduledoc false

  def add_metrics_options(metrics_options) do
    metrics_options
    |> events_handled()
    |> phoenix_endpoint()
  end

  defp events_handled(metrics_options) do
    [
      [
        metric_name: "events_handled.count",
        tags: [:app, :author, :dataset_id, :event_type],
        metric_type: :counter
      ]
      | metrics_options
    ]
  end

  defp phoenix_endpoint(metrics_options) do
    case Application.get_env(:telemetry_event, :add_poller) do
      true ->
        [
          [
            metric_name: "phoenix.endpoint.stop.duration",
            tags: [:path_info, :method],
            tag_values: fn %{conn: conn} ->
              %{path_info: Map.get(conn, :path_info) |> Enum.join("/"), method: Map.get(conn, :method)}
            end,
            metric_type: :distribution,
            unit: {:native, :millisecond},
            reporter_options: [buckets: [0.01, 0.025, 0.05, 0.1, 0.2, 0.5, 1]]
          ]
          | metrics_options
        ]

      _ ->
        metrics_options
    end
  end
end
