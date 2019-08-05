defmodule Reaper.Decoder.GeoJsonTest do
  use ExUnit.Case
  alias Reaper.ReaperConfig
  import Checkov

  @filename "#{__MODULE__}_temp_file"

  setup do
    on_exit(fn ->
      File.rm(@filename)
    end)

    :ok
  end

  describe "decode/2" do
    test "should return a list of feature maps" do
      data = %{
        "name" => "cool dataset",
        "features" => [
          %{"geometry" => "data"},
          %{"geometry" => "more data"}
        ]
      }

      structure =
        data
        |> Jason.encode!()

      File.write!(@filename, structure)

      {:ok, response} = Reaper.Decoder.GeoJson.decode({:file, @filename}, %ReaperConfig{sourceFormat: "geojson"})

      assert Map.get(data, "features") == response
    end

    data_test "throws error when given #{geojson_input}" do
      File.write!(@filename, geojson_input)
      response = Reaper.Decoder.GeoJson.decode({:file, @filename}, %ReaperConfig{sourceFormat: "geojson"})
      assert {:error, geojson_input, expected_error_message} == response

      where([
        [:geojson_input, :expected_error_message],
        ["{}", "Could not parse GeoJSON"],
        [~s|{"features": {}}|, "Could not parse GeoJSON"],
        ["invalid json", %Jason.DecodeError{data: "invalid json", position: 0, token: nil}],
        ["true", "Could not parse GeoJSON"]
      ])
    end
  end
end
