defmodule Reaper.Decoder.GtfsTest do
  use ExUnit.Case
  use Placebo
  alias Reaper.Decoder
  alias Reaper.ReaperConfig

  @filename "#{__MODULE__}_temp_file"

  setup do
    on_exit(fn ->
      File.rm(@filename)
    end)

    :ok
  end

  test "when given a GTFS protobuf body and a gtfs format it returns a list of entities" do
    {:ok, entities} = Decoder.Gtfs.decode({:file, "test/support/gtfs-realtime.pb"}, %ReaperConfig{sourceFormat: "gtfs"})
    assert Enum.count(entities) == 176
    assert entities |> List.first() |> Map.get(:id) == "1004"
  end

  test "bad gtfs messages return error tuple" do
    body = "baaad gtfs"
    message = "this is an error"
    File.write!(@filename, body)

    allow(TransitRealtime.FeedMessage.decode(any()), exec: fn _ -> raise message end)

    assert {:error, body, RuntimeError.exception(message: message)} ==
             Decoder.Gtfs.decode({:file, @filename}, %ReaperConfig{dataset_id: "ds2", sourceFormat: "gtfs"})
  end
end
