defmodule Reaper.Decoder.JsonTest do
  use ExUnit.Case
  use Placebo
  alias Reaper.ReaperConfig
  alias Reaper.Decoder
  import Checkov

  @filename "#{__MODULE__}_temp_file"

  setup do
    on_exit(fn ->
      File.rm(@filename)
    end)

    :ok
  end

  describe "decode/2" do
    test "when given a JSON string it returns it as a List of Maps" do
      expected = [
        %{"id" => Faker.UUID.v4()}
      ]

      structure = expected |> Jason.encode!()
      File.write!(@filename, structure)

      {:ok, result} = Decoder.Json.decode({:file, @filename}, %ReaperConfig{sourceFormat: "json"})

      assert expected == result
    end

    test "when given a JSON object it returns it as a List of Maps" do
      structure = "{}"

      File.write!(@filename, structure)
      {:ok, result} = Decoder.Json.decode({:file, @filename}, %ReaperConfig{sourceFormat: "json"})

      assert is_list(result)
      assert is_map(hd(result))
    end

    test "bad json messages return error tuple" do
      body = "baaad json"
      File.write!(@filename, body)

      assert {:error, body, Jason.DecodeError.exception(data: body, position: 0)} ==
               Reaper.Decoder.Json.decode({:file, @filename}, %ReaperConfig{dataset_id: "ds1", sourceFormat: "json"})
    end
  end

  describe "handle/1" do
    data_test "source_format of '#{format}' returns #{result}" do
      assert result == Decoder.Json.handle?(format)

      where([
        [:format, :result],
        ["json", true],
        ["csv", false],
        ["JSON", true],
        ["", false],
        [nil, false]
      ])
    end
  end
end
