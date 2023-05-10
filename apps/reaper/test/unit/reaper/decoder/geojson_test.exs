defmodule Reaper.Decoder.GeoJsonTest do
  use ExUnit.Case
  import Checkov

  alias SmartCity.TestDataGenerator, as: TDG

  @filename "#{__MODULE__}_temp_file"

  setup do
    on_exit(fn ->
      File.rm(@filename)
    end)

    :ok
  end

  describe "decode/2" do
    test "bad topLevelSelector returns error tuple" do
      ingestion_with_selector =
        TDG.create_ingestion(%{id: "ds1", topLevelSelector: "$.data[XX]", sourceFormat: "geojson"})

      body = %{data: %{features: [%{"geometry" => "data"}]}} |> Jason.encode!()
      File.write!(@filename, body)

      assert {:error, ^body, %Jaxon.ParseError{}} =
               Reaper.Decoder.Json.decode({:file, @filename}, ingestion_with_selector)
    end

    test "bad json with topLevelSelector returns error tuple" do
      ingestion_with_selector = TDG.create_ingestion(%{id: "ds1", topLevelSelector: "$.data", sourceFormat: "json"})

      bad_body = "{\"data\":{\"features\":[{\"geometry\":no_quotes}]}}"
      File.write!(@filename, bad_body)

      assert {:error, ^bad_body, %Jaxon.ParseError{}} =
               Reaper.Decoder.Json.decode({:file, @filename}, ingestion_with_selector)
    end

    data_test "throws error when given #{geojson_input} when sourceFormat is geojson" do
      File.write!(@filename, geojson_input)
      ingestion = TDG.create_ingestion(%{id: "ds1", sourceFormat: "geojson", topLevelSelector: nil})
      response = Reaper.Decoder.GeoJson.decode({:file, @filename}, ingestion)
      assert {:error, geojson_input, expected_error_message} == response

      where([
        [:geojson_input, :expected_error_message],
        ["{}", "Could not parse GeoJSON"],
        [~s|{"features": {}}|, "Could not parse GeoJSON"],
        ["invalid json", %Jason.DecodeError{data: "invalid json", position: 0, token: nil}],
        ["true", "Could not parse GeoJSON"]
      ])
    end

    data_test "throws error when given #{geojson_input} when sourceFormat is zip" do
      File.write!(@filename, geojson_input)
      ingestion = TDG.create_ingestion(%{id: "ds1", sourceFormat: "zip", topLevelSelector: nil})
      response = Reaper.Decoder.GeoJson.decode({:file, @filename}, ingestion)
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

  describe "handle/1" do
    data_test "source_format of '#{format}' returns #{result}" do
      assert result == Reaper.Decoder.GeoJson.handle?(format)

      where([
        [:format, :result],
        ["application/geo+json", true],
        ["geojson", false],
        ["json", false],
        ["csv", false],
        ["", false],
        [nil, false]
      ])
    end
  end
end
