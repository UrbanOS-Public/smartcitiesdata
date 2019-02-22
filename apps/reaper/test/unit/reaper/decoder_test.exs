defmodule Reaper.DecoderTest do
  use ExUnit.Case
  use Placebo
  alias Reaper.Decoder

  describe(".decode") do
    test "when given GTFS protobuf body and a gtfs format it returns it as a list of entities" do
      entities =
        "test/support/gtfs-realtime.pb"
        |> File.read!()
        |> Decoder.decode("gtfs")

      assert Enum.count(entities) == 176
      assert entities |> List.first() |> Map.get(:id) == "1004"
    end

    test "when given a CSV string body and a csv format it returns it as a Map" do
      structure =
        ~s(id, name, pet\n1, erin, bella\n2, ben, max\n\n)
        |> Decoder.decode("csv")

      assert structure |> List.first() |> Map.has_key?("name")
    end

    test "when given a JSON string body and a json format it returns it as a Map" do
      structure =
        ~s({"vehicle_id":22471,"update_time":"2019-01-02T16:15:50.662532+00:00","longitude":-83.0085,"latitude":39.9597})
        |> Decoder.decode("json")

      assert Map.has_key?(structure, "vehicle_id")
    end
  end
end
