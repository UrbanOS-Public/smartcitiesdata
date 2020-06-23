defmodule TelemetryEventTest do
  use ExUnit.Case

  test "should return Telemetry Metrics Counter when telemetry event metrics is called" do
    expected_event_name = [:any_events_handled]
    expected_measurement = :count
    expected_name = [:any_events_handled, :count]
    expected_tags = [:any_app, :any_author, :any_dataset_id, :any_event_type]
    expected_unit = :unit

    actual_metrics = TelemetryEvent.metrics() |> List.first()
    assert expected_event_name == Map.get(actual_metrics, :event_name)
    assert expected_measurement == Map.get(actual_metrics, :measurement)
    assert expected_name == Map.get(actual_metrics, :name)
    assert expected_tags == Map.get(actual_metrics, :tags)
    assert expected_unit == Map.get(actual_metrics, :unit)
  end

  test "should return `:ok` when all the mandatory fields are passed" do
    assert :ok ==
             [
               app: "any_app",
               author: "any_author",
               dataset_id: "any_dataset_id",
               event_type: "any_event_type"
             ]
             |> TelemetryEvent.add_event_count()
  end

  test "should return `:error` and error message when `app` is missing" do
    expected_error =
      {:error,
       %KeyError{
         key: :app,
         message: nil,
         term: [author: "any_author", dataset_id: "any_dataset_id", event_type: "any_event_type"]
       }}

    assert expected_error ==
             [
               author: "any_author",
               dataset_id: "any_dataset_id",
               event_type: "any_event_type"
             ]
             |> TelemetryEvent.add_event_count()
  end

  test "should return `:error` and error message when `author` is missing" do
    expected_error =
      {:error,
       %KeyError{
         key: :author,
         message: nil,
         term: [app: "any_app", dataset_id: "any_dataset_id", event_type: "any_event_type"]
       }}

    assert expected_error ==
             [
               app: "any_app",
               dataset_id: "any_dataset_id",
               event_type: "any_event_type"
             ]
             |> TelemetryEvent.add_event_count()
  end

  test "should return `:error` and error message when `dataset_id` is missing" do
    expected_error =
      {:error,
       %KeyError{
         key: :dataset_id,
         message: nil,
         term: [app: "any_app", author: "any_author", event_type: "any_event_type"]
       }}

    assert expected_error ==
             [
               app: "any_app",
               author: "any_author",
               event_type: "any_event_type"
             ]
             |> TelemetryEvent.add_event_count()
  end

  test "should return `:error` and error message when `event_type` is missing" do
    expected_error =
      {:error,
       %KeyError{
         key: :event_type,
         message: nil,
         term: [app: "any_app", author: "any_author", dataset_id: "any_dataset_id"]
       }}

    assert expected_error ==
             [
               app: "any_app",
               author: "any_author",
               dataset_id: "any_dataset_id"
             ]
             |> TelemetryEvent.add_event_count()
  end

  test "should return `:error` and error message when `app` is `nil`" do
    expected_error = {:error, %RuntimeError{message: "Keyword :app cannot be nil"}}

    assert expected_error ==
             [
               app: nil,
               author: "any_author",
               dataset_id: "any_dataset_id",
               event_type: "any_event_type"
             ]
             |> TelemetryEvent.add_event_count()
  end

  test "should return `:error` and error message when `author` is `nil`" do
    expected_error = {:error, %RuntimeError{message: "Keyword :author cannot be nil"}}

    assert expected_error ==
             [
               app: "any_app",
               author: nil,
               dataset_id: "any_dataset_id",
               event_type: "any_event_type"
             ]
             |> TelemetryEvent.add_event_count()
  end

  test "should return `:ok` when `dataset_id` is missing" do
    assert :ok ==
             [
               app: "any_app",
               author: "any_author",
               dataset_id: nil,
               event_type: "any_event_type"
             ]
             |> TelemetryEvent.add_event_count()
  end

  test "should return `:error` and error message when `event_type` is `nil`" do
    expected_error = {:error, %RuntimeError{message: "Keyword :event_type cannot be nil"}}

    assert expected_error ==
             [
               app: "any_app",
               author: "any_author",
               dataset_id: "any_dataset_id",
               event_type: nil
             ]
             |> TelemetryEvent.add_event_count()
  end
end
