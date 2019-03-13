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
    message = %{
      metadata: %{
        dataset_id: "cota.vehicle_positions",
        transformations: %{
          initialStartTime: "2019-02-22T20:06:03.975160Z",
          jsonDecodeDurationInMs: 0.052,
          performedTransformations: [
            %{durationInMs: 0.038, name: "Elixir.Voltron.Json.Trim", startTime: "2019-02-22T20:06:03.975221Z"}
          ],
          totalDurationInMs: 0.115
        }
      },
      operational: %{valkyrie: %{duration: 0, start_time: "2019-02-22T20:06:03.462424Z"}},
      payload: %{
        alert: nil,
        id: "1304",
        is_deleted: false,
        trip_update: nil,
        vehicle: %{
          congestion_level: nil,
          current_status: "IN_TRANSIT_TO",
          current_stop_sequence: nil,
          occupancy_status: nil,
          position: %{
            bearing: 180.0,
            latitude: 40.04230499267578,
            longitude: -82.97738647460938,
            odometer: nil,
            speed: 6.041108917997917e-6
          },
          stop_id: nil,
          timestamp: 1_550_865_941,
          trip: %{
            direction_id: nil,
            route_id: "008",
            schedule_relationship: nil,
            start_date: "20190222",
            start_time: nil,
            trip_id: "656921"
          },
          vehicle: %{id: "11304", label: "1304", license_plate: "Jessie123"}
        }
      }
    }

    expected = "779EEE80ED04E43F88064088236CDBA9"
    actual = HashPartitioner.partition(Jason.encode!(message), nil)
    assert actual == expected
  end

  test "Successfully returns hash for nil message" do
    message = nil

    actual = HashPartitioner.partition(message, nil)
    assert actual == "852438D026C018C4307B916406F98C62"
  end
end
