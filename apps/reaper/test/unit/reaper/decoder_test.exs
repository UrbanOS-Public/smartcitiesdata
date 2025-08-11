defmodule Reaper.DecoderTest do
  use ExUnit.Case
  import Mox
  alias Reaper.Decoder

  import SmartCity.TestHelper, only: [eventually: 1]
  alias SmartCity.TestDataGenerator, as: TDG
  
  use TempEnv, reaper: [
    decoder_implementations: [CsvDecoderMock, Reaper.Decoder.Unknown]
  ]
  
  setup :verify_on_exit!

  @filename "#{__MODULE__}_temp_file"

  setup do
    on_exit(fn ->
      File.rm(@filename)
    end)

    :ok
  end

  describe "failure to decode" do
    setup do
      # Set up the mock CSV decoder for both tests
      stub(CsvDecoderMock, :handle?, fn "csv" -> true; _ -> false end)
      
      # Override the implementations list to use our mock
      implementations = [
        Reaper.Decoder.Gtfs,
        Reaper.Decoder.Json,
        CsvDecoderMock,  # Replace Reaper.Decoder.Csv with mock
        Reaper.Decoder.Tsv,
        Reaper.Decoder.Xml,
        Reaper.Decoder.GeoJson,
        Reaper.Decoder.Unknown
      ]
      Application.put_env(:reaper, :decoder_implementations, implementations)
      
      on_exit(fn -> Application.delete_env(:reaper, :decoder_implementations) end)
      :ok
    end
    
    test "csv messages deadlettered and error raised" do
      stub(CsvDecoderMock, :handle?, fn "text/csv" -> true; _ -> false end)
      expect(CsvDecoderMock, :decode, fn _, _ -> 
        {:error, "this is the data part", "bad Csv"}
      end)
      
      body = "baaad csv"
      File.write(@filename, body)

      ingestion = TDG.create_ingestion(%{id: "ingestion-id", targetDatasets: ["ds1", "ds2"], sourceFormat: "text/csv"})

      assert_raise RuntimeError, "bad Csv", fn ->
        Decoder.decode({:file, @filename}, ingestion)
      end

      eventually(fn ->
        {:ok, dlqd_message} = DeadLetter.Carrier.Test.receive()

        refute dlqd_message == :empty

        assert dlqd_message.app == "reaper"
        assert dlqd_message.original_message == "this is the data part"
        assert dlqd_message.dataset_ids == ["ds1", "ds2"]
        assert dlqd_message.error == "\"bad Csv\""
      end)
    end

    test "invalid format messages deadlettered and error raised" do
      body = "c,s,v"
      File.write!(@filename, body)
      ingestion = TDG.create_ingestion(%{id: "ingestion-id", targetDatasets: ["ds1", "ds2"], sourceFormat: "CSY"})

      assert_raise RuntimeError, "application/octet-stream is an invalid format", fn ->
        Reaper.Decoder.decode({:file, @filename}, ingestion)
      end

      eventually(fn ->
        {:ok, dlqd_message} = DeadLetter.Carrier.Test.receive()
        refute dlqd_message == :empty

        assert dlqd_message.app == "reaper"
        assert dlqd_message.dataset_ids == ["ds1", "ds2"]

        assert dlqd_message.error ==
                 "%RuntimeError{message: \"application/octet-stream is an invalid format\"}"

        assert dlqd_message.original_message == ""
      end)
    end
  end
end
