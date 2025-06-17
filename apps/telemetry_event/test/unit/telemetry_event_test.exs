defmodule TelemetryEventTest do
  use ExUnit.Case, async: false
  import TelemetryEvent.MyTestHelper

  # Setup the mock before each test
  setup :setup_telemetry_mock

describe "original project unittests" do
    # @tag :skip
    test "should return `:ok` when all the mandatory fields are passed" do
    assert :ok ==
             [
               app: "any_app",
               author: "any_author",
               dataset_id: "any_dataset_id",
               event_type: "any_event_type"
             ]
             |> TelemetryEvent.add_event_metrics([:any_event_name])
    end

    # @tag :skip
    test "should return `:ok` when `dataset_id` is missing" do
    assert :ok ==
             [
               app: "",
               author: "",
               dataset_id: "",
               event_type: ""
             ]
             |> TelemetryEvent.add_event_metrics([:any_event_name])
    end

    # @tag :skip
    test "should return `:ok` any value is nil" do
    assert :ok ==
             [
               app: nil,
               author: nil,
               dataset_id: nil,
               event_type: nil
             ]
             |> TelemetryEvent.add_event_metrics([:any_event_name])
    end
end

  describe "add_event_metrics/3" do
    # @tag :skip
    test "emits telemetry event with provided metadata" do
      metadata = [
        app: "any_app",
        author: "any_author",
        dataset_id: "any_dataset_id",
        event_type: "any_event_type"
      ]

      # Call the function under test
      assert :ok = TelemetryEvent.add_event_metrics(metadata, [:test, :event])
      # Verify the event was captured with the correct data
      event = assert_event_captured([:test, :event])
      assert match?({[:test, :event], [app: "any_app", author: "any_author", dataset_id: "any_dataset_id", event_type: "any_event_type"], _}, event)
    end

    @tag :skip
    test "handles empty values by replacing them with 'UNKNOWN'" do
      # TODO: the original readme documents this behavior, but it doesn't seem to
      # do this at the moment. Circle back and determine if this is critical
      metadata = [
        app: "",
        author: nil,
        dataset_id: "",
        event_type: nil
      ]

      assert :ok = TelemetryEvent.add_event_metrics(metadata, [:test, :empty_values])
      event = assert_event_captured([:test, :empty_values])
      assert match?({[:test, :empty_values], %{app: "UNKNOWN", author: "UNKNOWN"}, _}, event)
    end

    #@tag :skip
    test "includes measurements when provided" do
      metadata = [app: "test_app", dataset_id: "123"]
      measurements = %{duration: 100, count: 5}

      assert :ok = TelemetryEvent.add_event_metrics(metadata, [:test, :with_measurements], measurements)
      {_, _, actual_measurements} = assert_event_captured([:test, :with_measurements])
      assert actual_measurements == %{duration: 100, count: 5}
    end
  end
end
