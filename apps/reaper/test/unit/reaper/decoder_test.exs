defmodule Reaper.DecoderTest do
  use ExUnit.Case
  use Placebo
  alias Reaper.Decoder
  alias SmartCity.TestDataGenerator, as: TDG

  describe(".decode") do
    test "when given GTFS protobuf body and a gtfs format it returns it as a list of entities" do
      entities =
        "test/support/gtfs-realtime.pb"
        |> File.read!()
        |> Decoder.decode("gtfs", nil)

      assert Enum.count(entities) == 176
      assert entities |> List.first() |> Map.get(:id) == "1004"
    end

    test "when given a CSV string body and a csv format it returns it as a Map" do
      dataset =
        TDG.create_dataset(%{id: "cool", technical: %{schema: [%{name: "id"}, %{name: "name"}, %{name: "pet"}]}})

      reaper_config =
        FixtureHelper.new_reaper_config(%{
          dataset_id: dataset.id,
          cadence: dataset.technical.cadence,
          sourceUrl: dataset.technical.sourceUrl,
          sourceFormat: dataset.technical.sourceFormat,
          schema: dataset.technical.schema,
          queryParams: dataset.technical.queryParams
        })

      expected = [
        %{"id" => "1", "name" => "Johnson", "pet" => "Spot"},
        %{"id" => "2", "name" => "Erin", "pet" => "Bella"},
        %{"id" => "3", "name" => "Ben", "pet" => "Max"}
      ]

      actual =
        ~s(1, Johnson, Spot\n2, Erin, Bella\n3, Ben, Max\n\n)
        |> Decoder.decode("csv", reaper_config.schema)

      assert actual == expected
    end

    test "when given a JSON string body and a json format it returns it as a Map" do
      structure =
        ~s({"vehicle_id":22471,"update_time":"2019-01-02T16:15:50.662532+00:00","longitude":-83.0085,"latitude":39.9597})
        |> Decoder.decode("json", nil)

      assert Map.has_key?(structure, "vehicle_id")
    end
  end

  describe "failure to decode" do
    test "json messages yoted and raises error" do
      body = "baaad json"

      allow(Yeet.process_dead_letter(any(), any(), any()), return: nil, meck_options: [:passthrough])

      assert [] == Reaper.Decoder.decode(body, "json", nil)

      assert_called Yeet.process_dead_letter(body, "Reaper",
                      exit_code: %Jason.DecodeError{data: "baaad json", position: 0, token: nil}
                    )
    end

    test "gtfs messages yoted and raises error" do
      body = "baaad gtfs"

      allow(Yeet.process_dead_letter(any(), any(), any()), return: nil, meck_options: [:passthrough])

      allow(TransitRealtime.FeedMessage.decode(any()), exec: fn _ -> raise "this is an error" end)

      assert [] == Reaper.Decoder.decode(body, "gtfs", nil)

      assert_called Yeet.process_dead_letter(body, "Reaper", exit_code: %RuntimeError{message: "this is an error"})
    end

    test "csv messages yoted and raises error" do
      body = "baaad csv"

      allow(Yeet.process_dead_letter(any(), any(), any()), return: nil, meck_options: [:passthrough])

      assert [] == Reaper.Decoder.decode(body, "csv", nil)

      assert_called Yeet.process_dead_letter(body, "Reaper",
                      exit_code: %Protocol.UndefinedError{description: "", protocol: Enumerable, value: nil}
                    )
    end

    test "invalid format messages yoted and raises error" do
      body = "c,s,v"

      allow(Yeet.process_dead_letter(any(), any(), any()), return: nil, meck_options: [:passthrough])

      assert [] == Reaper.Decoder.decode(body, "CSY", nil)

      assert_called Yeet.process_dead_letter(body, "Reaper",
                      exit_code: %RuntimeError{message: "CSY is an invalid format"}
                    )
    end
  end
end
