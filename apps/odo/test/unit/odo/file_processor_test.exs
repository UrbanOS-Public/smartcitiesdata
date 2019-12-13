defmodule Odo.Unit.FileProcessorTest do
  import SmartCity.Event, only: [file_ingest_start: 0, file_ingest_end: 0]
  import ExUnit.CaptureLog
  use ExUnit.Case
  use Placebo
  alias SmartCity.HostedFile

  @time DateTime.utc_now()

  setup do
    allow(Geomancer.geo_json(any()), return: {:ok, :geo_json_data})
    allow(File.write(any(), any()), return: :ok, meck_options: [:passthrough])
    allow(File.rm!(any()), return: :ok, meck_options: [:passthrough])
    allow(DateTime.utc_now(), return: @time, meck_options: [:passthrough])

    allow(StreamingMetrics.PrometheusMetricCollector.record_metrics(any(), any()),
      return: :irrelevant,
      meck_options: [:passthrough]
    )

    conversion_map = %Odo.ConversionMap{
      bucket: "hosted-files",
      original_key: "my-org/my-dataset.shapefile",
      converted_key: "my-org/my-dataset.geojson",
      download_path: "tmp/111.shapefile",
      converted_path: "tmp/111.geojson",
      conversion: &Geomancer.geo_json/1,
      dataset_id: 111
    }

    %{conversion_map: conversion_map}
  end

  describe "successful conversion of shapefile to geojson" do
    setup %{conversion_map: conversion_map} do
      allow(ExAws.request(any()), return: {:ok, :done})
      allow(Brook.Event.send(Odo.event_stream_instance(), any(), any(), any()), return: :ok, meck_options: [:passthrough])

      result = Odo.FileProcessor.process(conversion_map)

      %{result: result}
    end

    test "returns ok", %{result: result} do
      assert result == :ok
    end

    test "sends the file ingest events", %{conversion_map: conversion_map} do
      {:ok, expected_event} =
        HostedFile.new(%{
          dataset_id: conversion_map.dataset_id,
          mime_type: "application/geo+json",
          bucket: conversion_map.bucket,
          key: conversion_map.converted_key
        })

      assert_called(Brook.Event.send(Odo.event_stream_instance(), file_ingest_start(), :odo, expected_event), once())
      assert_called(Brook.Event.send(Odo.event_stream_instance(), file_ingest_end(), :odo, expected_event), once())
    end

    test "removes temporary files", %{conversion_map: conversion_map} do
      assert_called(File.rm!(conversion_map.download_path), once())
      assert_called(File.rm!(conversion_map.converted_path), once())
    end

    test "records correct metrics", %{conversion_map: conversion_map} do
      expected_dimensions = [
        dataset_id: conversion_map.dataset_id,
        file: conversion_map.original_key,
        start: DateTime.to_unix(@time)
      ]

      expected_metrics = [
        %{
          name: "file_conversion_success",
          value: 1,
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

  describe "unsuccessful conversion" do
    setup do
      allow(ExAws.request(any()),
        return: {:error, :econnrefused},
        meck_options: [:passthrough]
      )

      :ok
    end

    test "returns an error", %{conversion_map: conversion_map} do
      assert capture_log(fn ->
               assert Odo.FileProcessor.process(conversion_map) ==
                        {:error,
                         "File upload failed for dataset #{conversion_map.dataset_id}: Error downloading file for #{
                           conversion_map.bucket
                         }/#{conversion_map.original_key}: econnrefused"}
             end) =~ "econnrefused"
    end

    test "records correct metrics", %{conversion_map: conversion_map} do
      Odo.FileProcessor.process(conversion_map)

      expected_dimensions = [
        dataset_id: conversion_map.dataset_id,
        file: conversion_map.original_key,
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
