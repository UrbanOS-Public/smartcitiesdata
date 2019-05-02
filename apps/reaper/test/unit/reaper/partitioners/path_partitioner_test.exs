defmodule TestStruct.Person do
  defstruct [:id, :child]
end

defmodule Reaper.Partitioners.PathPartitionerTest do
  @moduledoc false

  use ExUnit.Case
  use Placebo
  alias Reaper.Partitioners.PathPartitioner

  setup do
    on_exit(fn -> unstub() end)
  end

  test "Successfully parses vehicle id from data message" do
    message = %{"a" => "1", "b" => "2"}
    key = PathPartitioner.partition(message, "b")

    assert key == "2"
  end

  test "Successfully returns message value at nested path" do
    message = %{"a" => "1", "b" => %{"c" => "2", "d" => %{"e" => "5"}}}
    path = "b.d.e"
    left = PathPartitioner.partition(message, path)
    right = "5"
    assert left == right
  end

  test "Successfully returns vehicle id from standard COTA message" do
    message = %{
      "alert" => nil,
      "id" => "1308",
      "is_deleted" => false,
      "trip_update" => nil,
      "vehicle" => %{
        "congestion_level" => nil,
        "current_status" => "IN_TRANSIT_TO",
        "current_stop_sequence" => nil,
        "occupancy_status" => nil,
        "position" => %{
          "bearing" => 180.0,
          "latitude" => 40.04230499267579,
          "longitude" => -82.97738647460938,
          "odometer" => nil,
          "speed" => 6.041108917997917e-6
        },
        "stop_id" => nil,
        "timestamp" => 1_550_865_941,
        "trip" => %{
          "direction_id" => nil,
          "route_id" => "008",
          "schedule_relationship" => nil,
          "start_date" => "20190222",
          "start_time" => nil,
          "trip_id" => "656921"
        },
        "vehicle" => %{"id" => "11304", "label" => "1304", "license_plate" => "Jessie123"}
      }
    }

    path = "vehicle.vehicle.id"
    left = PathPartitioner.partition(message, path)
    right = "11304"
    assert left == right
  end

  test "returns correct value from structs" do
    payload = %TestStruct.Person{
      id: 1,
      child: %TestStruct.Person{
        id: 2,
        child: %TestStruct.Person{
          id: 3,
          child: nil
        }
      }
    }

    assert 3 == PathPartitioner.partition(payload, "child.child.id")
  end

  test "Throws error attempting to partition a NIL path" do
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

    path = nil

    assert_raise FunctionClauseError, fn ->
      PathPartitioner.partition(message, path)
    end
  end

  test "Throws error attempting to partition a NIL message with a NIL path" do
    message = nil
    path = nil

    assert_raise FunctionClauseError, fn ->
      PathPartitioner.partition(message, path)
    end
  end
end
