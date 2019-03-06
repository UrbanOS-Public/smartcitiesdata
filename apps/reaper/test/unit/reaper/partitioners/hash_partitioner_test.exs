defmodule Reaper.Partitioners.HashPartitionerTest do
  @moduledoc false

  use ExUnit.Case
  use Placebo
  alias Reaper.Partitioners.HashPartitioner

  setup do
    on_exit(fn -> unstub() end)
  end

  test "Successfully produces hash for valid message" do
    message = ~s({"a": "1", "b": "2"})
    expected = "556DF92BA1150B4087D6D5EC9080AC9A"
    actual = HashPartitioner.partition(message, nil)

    assert actual == expected
  end

  test "Successfully returns hash for yet another valid message" do
    message = ~s({"a": "1", "b": {"c": "2", "d": {"e": "5"}}})
    expected = "7ED90FDE691552492EC5E4A11CD34D7E"
    actual = HashPartitioner.partition(message, nil)
    assert actual == expected
  end

  test "Successfully returns hash for code valid message" do
    message =
      ~s({"metadata":{"dataset_id":"cota.vehicle_positions","transformations":{"initialStartTime":"2019-02-22T20:06:03.975160Z","jsonDecodeDurationInMs":0.052,"performedTransformations":[{"durationInMs":0.038,"name":"Elixir.Voltron.Json.Trim","startTime":"2019-02-22T20:06:03.975221Z"}],"totalDurationInMs":0.115}},"operational":{"valkyrie":{"duration":0,"start_time":"2019-02-22T20:06:03.462424Z"}},"payload":{"alert":null,"id":"1304","is_deleted":false,"trip_update":null,"vehicle":{"congestion_level":null,"current_status":"IN_TRANSIT_TO","current_stop_sequence":null,"occupancy_status":null,"position":{"bearing":180.0,"latitude":40.04230499267578,"longitude":-82.97738647460938,"odometer":null,"speed":6.041108917997917e-6},"stop_id":null,"timestamp":1550865941,"trip":{"direction_id":null,"route_id":"008","schedule_relationship":null,"start_date":"20190222","start_time":null,"trip_id":"656921"},"vehicle":{"id":"11304","label":"1304","license_plate": "Jessie123"}}}})

    expected = "9506BCC8A579A43CEDBF6F1465CE369C"
    actual = HashPartitioner.partition(message, nil)
    assert actual == expected
  end

  test "Successfully returns hash for nil message" do
    message = nil

    actual = HashPartitioner.partition(message, nil)
    assert actual == "852438D026C018C4307B916406F98C62"
  end
end
