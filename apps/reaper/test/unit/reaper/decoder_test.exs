defmodule Reaper.DecoderTest do
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

  describe "failure to decode" do
    test "csv messages yoted and raises error" do
      body = "baaad csv"
      File.write(@filename, body)

      allow Decoder.Csv.decode(any(), any()),
        return: {:error, "this is the data part", "bad Csv"},
        meck_options: [:passthrough]

      allow(Yeet.process_dead_letter(any(), any(), any(), any()), return: nil, meck_options: [:passthrough])

      assert_raise RuntimeError, "bad Csv", fn ->
        Decoder.decode({:file, @filename}, %ReaperConfig{dataset_id: "ds1", sourceFormat: "csv"})
      end

      assert_called Yeet.process_dead_letter("ds1", "this is the data part", "Reaper", error: "bad Csv")
    end

    test "invalid format messages yoted and raises error" do
      body = "c,s,v"
      File.write!(@filename, body)

      allow(Yeet.process_dead_letter(any(), any(), any(), any()), return: nil, meck_options: [:passthrough])

      assert_raise RuntimeError, "CSY is an invalid format", fn ->
        Reaper.Decoder.decode({:file, @filename}, %ReaperConfig{dataset_id: "ds1", sourceFormat: "CSY"})
      end

      assert_called Yeet.process_dead_letter("ds1", "", "Reaper",
                      error: %RuntimeError{message: "CSY is an invalid format"}
                    )
    end
  end
end
