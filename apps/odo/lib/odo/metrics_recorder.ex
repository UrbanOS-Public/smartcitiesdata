defmodule Odo.MetricsRecorder do
  @moduledoc """
  Main interface for recording app metrics
  """
  require Logger

  def record_file_conversion_metrics(dataset_id, file_key, success, start_date_time \\ DateTime.utc_now()) do
    success_value = if success, do: 1, else: 0
    duration = Time.diff(DateTime.utc_now(), start_date_time, :millisecond)

    labels = [
      dataset_id: dataset_id,
      file: file_key,
      start: DateTime.to_unix(start_date_time)
    ]

    with :ok <- add_file_conversion([:file_conversion_success], labels, success_value),
         :ok <- add_file_conversion([:file_conversion_duration], labels, duration) do
      :ok
    else
      error -> Logger.warn("Unable to record file conversion metrics : #{inspect(error)}")
    end
  end

  defp add_file_conversion(metrics_name, dimensions, gauge) do
    [
      app: "odo",
      dataset_id: Keyword.fetch!(dimensions, :dataset_id),
      file: Keyword.fetch!(dimensions, :file),
      start: Keyword.fetch!(dimensions, :start)
    ]
    |> TelemetryEvent.add_event_metrics(metrics_name, value: %{gauge: gauge})
  end
end
