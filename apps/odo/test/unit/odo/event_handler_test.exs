defmodule Odo.Unit.EventHandlerTest do
  use ExUnit.Case
  use Placebo
  import SmartCity.Event, only: [file_ingest_end: 0]
  alias SmartCity.HostedFile

  @time DateTime.utc_now()

  setup do
    allow(DateTime.utc_now(), return: @time, meck_options: [:passthrough])
    expect(TelemetryEvent.add_event_metrics(any(), [:events_handled]), return: :ok)

    :ok
  end

  describe "unsupported conversion" do
    setup do
      {:ok, hosted_file_event} =
        HostedFile.new(%{
          dataset_id: "some_id",
          bucket: "some_bucket",
          key: "some_org/some_data.unsupported",
          mime_type: "application/zip"
        })

      event = %Brook.Event{type: file_ingest_end(), author: :some_author, data: hosted_file_event, create_ts: @time}

      result = Odo.EventHandler.handle_event(event)

      %{hosted_file_event: hosted_file_event, result: result}
    end

    test "returns discard", %{result: result} do
      assert :discard == result
    end

    test "records failure metrics", %{hosted_file_event: hosted_file_event} do
      expected_dimensions = [
        dataset_id: hosted_file_event.dataset_id,
        file: hosted_file_event.key,
        start: DateTime.to_unix(@time)
      ]

      expected_metrics = [
        %{
          name: "file_conversion_success",
          value: 0,
          dimensions: expected_dimensions,
          type: :gauge
        },
        %{
          name: "file_conversion_duration",
          value: 0,
          dimensions: expected_dimensions,
          type: :gauge
        }
      ]

      assert_called(StreamingMetrics.PrometheusMetricCollector.record_metrics(expected_metrics, "odo"))
    end
  end
end
