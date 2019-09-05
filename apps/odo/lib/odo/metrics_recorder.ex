defmodule Odo.MetricsRecorder do
  require Logger

  @metric_collector Application.get_env(:odo, :collector)

  def record_file_conversion_metrics(dataset_id, file_key, success, start_date_time \\ DateTime.utc_now()) do
    success_value = if success, do: 1, else: 0
    duration = Time.diff(DateTime.utc_now(), start_date_time, :millisecond)

    labels = [
      dataset_id: dataset_id,
      file: file_key,
      start: DateTime.to_unix(start_date_time)
    ]

    @metric_collector.record_metrics(
      [
        @metric_collector.gauge_metric(success_value, "file_conversion_success", labels),
        @metric_collector.gauge_metric(duration, "file_conversion_duration", labels)
      ],
      "odo"
    )
    |> case do
      {:error, err} -> Logger.warn("Unable to record file conversion metrics : #{inspect(err)}")
      _ -> :ok
    end
  end
end
