defmodule TelemetryEvent.Helper.AddMetrics do
  @moduledoc false

  def add_metrics_options() do
    metrics_options =
      Application.get_env(:telemetry_event, :metrics_options)
      |> List.wrap()

    add_metrics =
      [
        :events_handled_count
        | Application.get_env(:telemetry_event, :add_metrics)
          |> List.wrap()
      ]
      |> Enum.map(fn metrics -> add_metrics(metrics) end)

    add_metrics ++ metrics_options
  end

  defp add_metrics(:events_handled_count) do
    [
      metric_name: "events_handled.count",
      tags: [:app, :author, :dataset_id, :event_type],
      metric_type: :counter
    ]
  end

  defp add_metrics(:dead_letters_handled_count) do
    [
      metric_name: "dead_letters_handled.count",
      tags: [:dataset_id, :reason],
      metric_type: :counter
    ]
  end

  defp add_metrics(:phoenix_endpoint_stop_duration) do
    [
      metric_name: "phoenix.endpoint.stop.duration",
      tags: [:app, :end_point, :method],
      tag_values: fn %{conn: conn} ->
        %{app: app(conn), end_point: end_point(conn), method: Map.get(conn, :method)}
      end,
      metric_type: :distribution,
      unit: {:native, :millisecond},
      reporter_options: [buckets: [10, 50, 100, 250, 500, 1000, 2000]]
    ]
  end

  defp add_metrics(:dataset_total_count) do
    [
      metric_name: "dataset_total.count",
      tags: [:app],
      metric_type: :last_value
    ]
  end

  defp app(conn) do
    phoenix_endpoint = "#{Map.get(conn, :private) |> Map.get(:phoenix_endpoint)}"

    Regex.replace(~r/[A-Z]/, phoenix_endpoint, fn elixir_app_name -> "_#{elixir_app_name}" end)
    |> String.replace_leading("_Elixir._", "")
    |> String.replace_trailing("_Web._Endpoint", "")
    |> String.downcase()
  end

  defp end_point(conn) do
    request_path = Map.get(conn, :request_path)

    Map.get(conn, :path_params)
    |> Enum.reduce(request_path, fn {key, value}, new_request_path ->
      String.replace(new_request_path, "#{value}", ":#{key}")
    end)
  end
end
