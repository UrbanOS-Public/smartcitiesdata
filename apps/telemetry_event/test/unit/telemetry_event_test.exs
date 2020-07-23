defmodule TelemetryEventTest do
  use ExUnit.Case

  test "should return `:ok` when all the mandatory fields are passed" do
    assert :ok ==
             [
               app: "any_app",
               author: "any_author",
               dataset_id: "any_dataset_id",
               event_type: "any_event_type"
             ]
             |> TelemetryEvent.add_event_count([:any_event_name])
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
             |> TelemetryEvent.add_event_count([:any_event_name])
  end

  test "should return `:ok` when `dataset_id` is missing" do
    assert :ok ==
             [
               app: "any_app",
               author: "any_author",
               dataset_id: nil,
               event_type: "any_event_type"
             ]
             |> TelemetryEvent.add_event_count([:any_event_name])
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
             |> TelemetryEvent.add_event_count([:any_event_name])
  end
end
