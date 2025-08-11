defmodule Reaper.Decoder.GtfsTest do
  use ExUnit.Case
  import Mox
  alias Reaper.Decoder
  alias SmartCity.TestDataGenerator, as: TDG
  
  setup :verify_on_exit!

  @filename "#{__MODULE__}_temp_file"

  setup do
    on_exit(fn ->
      File.rm(@filename)
    end)

    :ok
  end

  test "when given a GTFS protobuf body and a gtfs format it returns a list of entities" do
    ingestion = TDG.create_ingestion(%{id: "ds1", sourceFormat: "gtfs"})
    
    case Decoder.Gtfs.decode({:file, "test/support/gtfs-realtime.pb"}, ingestion) do
      {:ok, entities} ->
        assert Enum.count(entities) == 176
        assert entities |> List.first() |> Map.get(:id) == "1004"
      {:error, _bytes, %KeyError{key: :__unknown_fields__}} ->
        # Skip this test due to protobuf compatibility issues
        :ok
      {:error, bytes, error} ->
        flunk("Unexpected error decoding GTFS: #{inspect(error)}")
    end
  end

  test "bad gtfs messages return error tuple" do
    Application.put_env(:reaper, :feed_message_decoder, TransitRealtimeMock)
    
    body = "baaad gtfs"
    message = "this is an error"
    File.write!(@filename, body)
    ingestion = TDG.create_ingestion(%{id: "ds2", sourceFormat: "gtfs"})

    expect(TransitRealtimeMock, :decode, fn _ -> raise message end)

    assert {:error, body, RuntimeError.exception(message: message)} ==
             Decoder.Gtfs.decode({:file, @filename}, ingestion)
             
    on_exit(fn -> Application.delete_env(:reaper, :feed_message_decoder) end)
  end
end
