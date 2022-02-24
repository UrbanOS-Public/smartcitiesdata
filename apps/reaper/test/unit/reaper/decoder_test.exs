defmodule Reaper.DecoderTest do
  use ExUnit.Case
  use Placebo
  alias Reaper.Decoder

  import SmartCity.TestHelper, only: [eventually: 1]
  alias SmartCity.TestDataGenerator, as: TDG

  @filename "#{__MODULE__}_temp_file"

  setup do
    on_exit(fn ->
      File.rm(@filename)
    end)

    :ok
  end

  describe "failure to decode" do
    test "csv messages deadlettered and error raised" do
      body = "baaad csv"
      File.write(@filename, body)

      ingestion = TDG.create_ingestion(%{id: "ingestion-id", targetDataset: "ds1", sourceFormat: "csv"})

      allow(Decoder.Csv.decode(any(), any()),
        return: {:error, "this is the data part", "bad Csv"},
        meck_options: [:passthrough]
      )

      assert_raise RuntimeError, "bad Csv", fn ->
        Decoder.decode({:file, @filename}, ingestion)
      end

      eventually(fn ->
        {:ok, dlqd_message} = DeadLetter.Carrier.Test.receive()

        refute dlqd_message == :empty

        assert dlqd_message.app == "reaper"
        assert dlqd_message.original_message == "this is the data part"
        assert dlqd_message.dataset_id == "ds1"
        assert dlqd_message.error == "bad Csv"
      end)
    end

    test "invalid format messages deadlettered and error raised" do
      body = "c,s,v"
      File.write!(@filename, body)
      ingestion = TDG.create_ingestion(%{id: "ingestion-id", targetDataset: "ds1", sourceFormat: "CSY"})

      assert_raise RuntimeError, "application/octet-stream is an invalid format", fn ->
        Reaper.Decoder.decode({:file, @filename}, ingestion)
      end

      eventually(fn ->
        {:ok, dlqd_message} = DeadLetter.Carrier.Test.receive()
        refute dlqd_message == :empty

        assert dlqd_message.app == "reaper"
        assert dlqd_message.dataset_id == "ds1"

        assert dlqd_message.error ==
                 "** (RuntimeError) application/octet-stream is an invalid format"

        assert dlqd_message.original_message == ""
      end)
    end
  end
end
