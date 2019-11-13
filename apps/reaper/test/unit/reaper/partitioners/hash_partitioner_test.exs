defmodule Reaper.Partitioners.HashPartitionerTest do
  @moduledoc false

  use ExUnit.Case
  use Placebo
  alias Reaper.Partitioners.HashPartitioner

  setup do
    on_exit(fn -> unstub() end)
  end

  test "Successfully produces hash for valid message" do
    message = %{a: "1", b: "2"}
    expected = "7D7D9E8E60D8D8A8C62F78E388E29EB7"
    actual = HashPartitioner.partition(Jason.encode!(message), nil)

    assert actual == expected
  end

  test "Successfully returns hash for yet another valid message" do
    message = %{a: "1", b: %{c: "2", d: %{e: "5"}}}
    expected = "0887929F124F2AF4BD2961A0B68A1C7A"
    actual = HashPartitioner.partition(Jason.encode!(message), nil)
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
        id: "5433",
        is_deleted: false,
        trip_update: nil,
        vehicle: %{
          congestion_level: nil,
          current_status: "IN_TRANSIT_TO",
          current_stop_sequence: nil,
          occupancy_status: nil,
          position: %{
            bearing: 180.0,
            latitude: 40.04230499267999,
            longitude: -82.97738647460111,
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
          vehicle: %{id: "5433", label: "1304", license_plate: "Jessie123"}
        }
      }
    }

    expected = "7BE92EBA8F67DC5A0174B146C9F453B6"
    actual = HashPartitioner.partition(Jason.encode!(message), nil)
    assert actual == expected
  end

  test "Successfully returns hash for nil message" do
    message = nil

    actual = HashPartitioner.partition(message, nil)
    assert actual == "852438D026C018C4307B916406F98C62"
  end
end
