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
            tags: [:end_point, :method],
            tag_values: fn %{conn: conn} ->
              %{end_point: end_point(conn), method: Map.get(conn, :method)}
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

  defp end_point(conn) do
    request_path = Map.get(conn, :request_path)

    Map.get(conn, :path_params)
    |> Enum.reduce(request_path, fn {key, value}, new_request_path -> String.replace(new_request_path, "#{value}", ":#{key}") end)
  end
end
