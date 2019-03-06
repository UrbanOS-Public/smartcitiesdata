defmodule Reaper.Partitioners.SinglePartitionerTest do
  @moduledoc false

  use ExUnit.Case
  use Placebo
  alias Reaper.Partitioners.SinglePartitioner

  setup do
    on_exit(fn -> unstub() end)
  end

  test "Successfully produces Single for valid message" do
    message = ~s({"a": "1", "b": "2"})
    expected = "SINGLE"
    actual = SinglePartitioner.partition(message, nil)

    assert actual == expected
  end

  test "Successfully returns Single for yet another valid message" do
    message = ~s({"a": "1", "b": {"c": "2", "d": {"e": "5"}}})
    expected = "SINGLE"
    actual = SinglePartitioner.partition(message, nil)
    assert actual == expected
  end

  test "Successfully returns Single for code valid message" do
    message =
      ~s({"metadata":{"dataset_id":"cota.vehicle_positions","transformations":{"initialStartTime":"2019-02-22T20:06:03.975160Z","jsonDecodeDurationInMs":0.052,"performedTransformations":[{"durationInMs":0.038,"name":"Elixir.Voltron.Json.Trim","startTime":"2019-02-22T20:06:03.975221Z"}],"totalDurationInMs":0.115}},"operational":{"valkyrie":{"duration":0,"start_time":"2019-02-22T20:06:03.462424Z"}},"payload":{"alert":null,"id":"1304","is_deleted":false,"trip_update":null,"vehicle":{"congestion_level":null,"current_status":"IN_TRANSIT_TO","current_stop_sequence":null,"occupancy_status":null,"position":{"bearing":180.0,"latitude":40.04230499267578,"longitude":-82.97738647460938,"odometer":null,"speed":6.041108917997917e-6},"stop_id":null,"timestamp":1550865941,"trip":{"direction_id":null,"route_id":"008","schedule_relationship":null,"start_date":"20190222","start_time":null,"trip_id":"656921"},"vehicle":{"id":"11304","label":"1304","license_plate": "Jessie123"}}}})

    expected = "SINGLE"
    actual = SinglePartitioner.partition(message, nil)
    assert actual == expected
  end

  test "Successfully returns Single for nil message" do
    message = nil

    actual = SinglePartitioner.partition(message, nil)
    assert actual == "SINGLE"
  end
end
