defmodule Reaper.Partitioners.JsonPartitionerTest do
  @moduledoc false

  use ExUnit.Case
  use Placebo
  alias Reaper.Partitioners.JsonPartitioner

  setup do
    on_exit(fn -> unstub() end)
  end

  test "Successfully parses vehicle id from data message" do
    message = ~s({"a": "1", "b": "2"})
    key = JsonPartitioner.partition(message, "b")

    assert key == "2"
  end

  test "Successfully returns message value at nested path" do
    message = ~s({"a": "1", "b": {"c": "2", "d": {"e": "5"}}})
    path = "b.d.e"
    left = JsonPartitioner.partition(message, path)
    right = "5"
    assert left == right
  end

  test "Successfully returns vehicle id from standard COTA message" do
    message =
      ~s({"metadata":{"dataset_id":"cota.vehicle_positions","transformations":{"initialStartTime":"2019-02-22T20:06:03.975160Z","jsonDecodeDurationInMs":0.052,"performedTransformations":[{"durationInMs":0.038,"name":"Elixir.Voltron.Json.Trim","startTime":"2019-02-22T20:06:03.975221Z"}],"totalDurationInMs":0.115}},"operational":{"valkyrie":{"duration":0,"start_time":"2019-02-22T20:06:03.462424Z"}},"payload":{"alert":null,"id":"1304","is_deleted":false,"trip_update":null,"vehicle":{"congestion_level":null,"current_status":"IN_TRANSIT_TO","current_stop_sequence":null,"occupancy_status":null,"position":{"bearing":180.0,"latitude":40.04230499267578,"longitude":-82.97738647460938,"odometer":null,"speed":6.041108917997917e-6},"stop_id":null,"timestamp":1550865941,"trip":{"direction_id":null,"route_id":"008","schedule_relationship":null,"start_date":"20190222","start_time":null,"trip_id":"656921"},"vehicle":{"id":"11304","label":"1304","license_plate": "Jessie123"}}}})

    path = "payload.vehicle.vehicle.id"
    left = JsonPartitioner.partition(message, path)
    right = "11304"
    assert left == right
  end

  test "Throws error attempting to partition a NIL message" do
    message = nil
    path = "payload.vehicle.vehicle.id"

    assert_raise ArgumentError, fn ->
      JsonPartitioner.partition(message, path)
    end
  end

  test "Throws error attempting to partition a NIL path" do
    message =
      ~s({"metadata":{"dataset_id":"cota.vehicle_positions","transformations":{"initialStartTime":"2019-02-22T20:06:03.975160Z","jsonDecodeDurationInMs":0.052,"performedTransformations":[{"durationInMs":0.038,"name":"Elixir.Voltron.Json.Trim","startTime":"2019-02-22T20:06:03.975221Z"}],"totalDurationInMs":0.115}},"operational":{"valkyrie":{"duration":0,"start_time":"2019-02-22T20:06:03.462424Z"}},"payload":{"alert":null,"id":"1304","is_deleted":false,"trip_update":null,"vehicle":{"congestion_level":null,"current_status":"IN_TRANSIT_TO","current_stop_sequence":null,"occupancy_status":null,"position":{"bearing":180.0,"latitude":40.04230499267578,"longitude":-82.97738647460938,"odometer":null,"speed":6.041108917997917e-6},"stop_id":null,"timestamp":1550865941,"trip":{"direction_id":null,"route_id":"008","schedule_relationship":null,"start_date":"20190222","start_time":null,"trip_id":"656921"},"vehicle":{"id":"11304","label":"1304","license_plate": "Jessie123"}}}})

    path = nil

    assert_raise FunctionClauseError, fn ->
      JsonPartitioner.partition(message, path)
    end
  end

  test "Throws error attempting to partition a NIL message with a NIL path" do
    message = nil
    path = nil

    assert_raise FunctionClauseError, fn ->
      JsonPartitioner.partition(message, path)
    end
  end
end
