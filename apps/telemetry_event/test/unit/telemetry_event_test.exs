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

  test "should return `:ok` when `dataset_id` is missing" do
    assert :ok ==
             [
               app: "",
               author: "",
               dataset_id: "",
               event_type: ""
             ]
             |> TelemetryEvent.add_event_count([:any_event_name])
  end

  test "should return `:ok` any value is nil" do
    assert :ok ==
             [
               app: nil,
               author: nil,
               dataset_id: nil,
               event_type: nil
             ]
             |> TelemetryEvent.add_event_count([:any_event_name])
  end
end
