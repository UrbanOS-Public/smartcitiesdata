defmodule Reaper.Decoder.JsonTest do
  use ExUnit.Case
  use Placebo
  alias Reaper.ReaperConfig
  alias Reaper.Decoder

  @filename "#{__MODULE__}_temp_file"

  setup do
    on_exit(fn ->
      File.rm(@filename)
    end)

    :ok
  end

  test "when given a JSON string body and a json format it returns it as a Map" do
    structure =
      ~s({"vehicle_id":22471,"update_time":"2019-01-02T16:15:50.662532+00:00","longitude":-83.0085,"latitude":39.9597})

    File.write!(@filename, structure)
    {:ok, result} = Decoder.Json.decode({:file, @filename}, %ReaperConfig{sourceFormat: "json"})
    assert Map.has_key?(result, "vehicle_id")
  end

  test "bad json messages return error tuple" do
    body = "baaad json"
    File.write!(@filename, body)

    assert {:error, body, Jason.DecodeError.exception(data: body, position: 0)} ==
             Reaper.Decoder.Json.decode({:file, @filename}, %ReaperConfig{dataset_id: "ds1", sourceFormat: "json"})
  end
end
