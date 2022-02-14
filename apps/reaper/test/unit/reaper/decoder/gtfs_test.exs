defmodule Reaper.Decoder.GtfsTest do
  use ExUnit.Case
  use Placebo
  alias Reaper.Decoder
  alias SmartCity.TestDataGenerator, as: TDG

  @filename "#{__MODULE__}_temp_file"

  setup do
    on_exit(fn ->
      File.rm(@filename)
    end)

    :ok
  end

  test "when given a GTFS protobuf body and a gtfs format it returns a list of entities" do
    ingestion = TDG.create_ingestion(%{id: "ds1", sourceFormat: "gtfs"})
    {:ok, entities} = Decoder.Gtfs.decode({:file, "test/support/gtfs-realtime.pb"}, ingestion)
    assert Enum.count(entities) == 176
    assert entities |> List.first() |> Map.get(:id) == "1004"
  end

  test "bad gtfs messages return error tuple" do
    body = "baaad gtfs"
    message = "this is an error"
    File.write!(@filename, body)
    ingestion = TDG.create_ingestion(%{id: "ds2", sourceFormat: "gtfs"})

    allow(TransitRealtime.FeedMessage.decode(any()), exec: fn _ -> raise message end)

    assert {:error, body, RuntimeError.exception(message: message)} ==
             Decoder.Gtfs.decode({:file, @filename}, ingestion)
  end
end
