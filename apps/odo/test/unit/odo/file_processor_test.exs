defmodule Odo.Unit.FileProcessorTest do
  import SmartCity.Event, only: [file_upload: 0]
  import ExUnit.CaptureLog
  use ExUnit.Case
  use Placebo
  alias SmartCity.HostedFile

  setup do
    allow(Geomancer.geo_json(any()), return: {:ok, :geo_json_data})
    allow(File.write(any(), any()), return: :ok, meck_options: [:passthrough])
    allow(File.rm!(any()), return: :ok, meck_options: [:passthrough])

    allow(StreamingMetrics.PrometheusMetricCollector.record_metrics(any(), any()),
      return: :irrelevant,
      meck_options: [:passthrough]
    )

    %{}
  end

  describe "successful conversion of shapefile to geojson" do
    setup do
      allow(ExAws.request(any()), return: {:ok, :done})
      allow(Brook.Event.send(file_upload(), any(), any()), return: :ok, meck_options: [:passthrough])

      conversion_map = %{
        bucket: "hosted-files",
        original_key: "my-org/my-dataset.shapefile",
        converted_key: "my-org/my-dataset.geojson",
        download_path: "tmp/111.shapefile",
        converted_path: "tmp/111.geojson",
        conversion: &Geomancer.geo_json/1,
        id: 111
      }

      result = Odo.FileProcessor.process(conversion_map)

      %{result: result}
    end

    test "returns ok", %{result: result} do
      assert result == :ok
    end

    test "sends the file_upload event" do
      {:ok, expected_event} =
        HostedFile.new(%{
          dataset_id: 111,
          mime_type: "application/geo+json",
          bucket: "hosted-files",
          key: "my-org/my-dataset.geojson"
        })

      assert_called(Brook.Event.send(file_upload(), :odo, expected_event), once())
    end

    test "removes temporary files" do
      assert_called(File.rm!("tmp/111.shapefile"), once())
      assert_called(File.rm!("tmp/111.geojson"), once())
    end

    test "records correct metrics" do
      expected_dimensions = [dataset_id: 111, file: "my-org/my-dataset.shapefile"]

      expected_metrics = [
        %{
          name: "file_process_success",
          value: 1,
          dimensions: expected_dimensions,
          type: :gauge
        },
        %{
          name: "file_process_duration",
          dimensions: expected_dimensions,
          type: :gauge
        }
      ]

      assert_called(StreamingMetrics.PrometheusMetricCollector.record_metrics(expected_metrics, "odo"))
    end
  end

  describe "unsuccessful conversion" do
    setup do
      allow(ExAws.request(any()),
        return: {:error, :econnrefused},
        meck_options: [:passthrough]
      )

      shapefile_attempt = %{
        bucket: "hosted-files",
        original_key: "my-org/oh-no.zip",
        converted_key: "my-org/my-dataset.geojson",
        download_path: "tmp/113.shapefile",
        converted_path: "tmp/113.geojson",
        conversion: &Geomancer.geo_json/1,
        id: 113
      }

      %{shapefile_attempt: shapefile_attempt}
    end

    test "returns an error", %{shapefile_attempt: shapefile_attempt} do
      assert capture_log(fn ->
               assert Odo.FileProcessor.process(shapefile_attempt) ==
                        {:error,
                         "File upload failed for dataset 113: Error downloading file for hosted-files/my-org/oh-no.zip: econnrefused"}
             end) =~ "econnrefused"
    end

    test "records correct metrics", %{shapefile_attempt: shapefile_attempt} do
      Odo.FileProcessor.process(shapefile_attempt)

      expected_dimensions = [dataset_id: 113, file: "my-org/oh-no.zip"]

      expected_metrics = [
        %{
          name: "file_process_success",
          value: 0,
          dimensions: expected_dimensions,
          type: :gauge
        },
        %{
          name: "file_process_duration",
          dimensions: expected_dimensions,
          type: :gauge
        }
      ]

      assert_called(StreamingMetrics.PrometheusMetricCollector.record_metrics(expected_metrics, "odo"))
    end
  end
end
