defmodule Reaper.Decoder.CsvTest do
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

  describe "decode/2" do
    test "discards CSV headers" do
      dataset =
        TDG.create_dataset(%{
          id: "with-headers",
          technical: %{sourceFormat: "csv", schema: [%{name: "id"}, %{name: "name"}]}
        })

      reaper_config =
        FixtureHelper.new_reaper_config(%{
          dataset_id: dataset.id,
          cadence: dataset.technical.cadence,
          sourceUrl: dataset.technical.sourceUrl,
          sourceFormat: dataset.technical.sourceFormat,
          schema: dataset.technical.schema,
          sourceQueryParams: dataset.technical.sourceQueryParams
        })

      expected = [
        %{"id" => "id", "name" => " something different"},
        %{"id" => "1", "name" => " Woody"},
        %{"id" => "2", "name" => " Buzz"}
      ]

      File.write!(@filename, ~s|id, name\nid, something different\n1, Woody\n2, Buzz\n|)

      {:ok, actual} =
        {:file, @filename}
        |> Decoder.Csv.decode(reaper_config)

      assert Enum.into(actual, []) == expected
    end

    test "converts CSV to map" do
      dataset =
        TDG.create_dataset(%{
          id: "cool",
          technical: %{sourceFormat: "csv", schema: [%{name: "id"}, %{name: "name"}, %{name: "pet"}]}
        })

      reaper_config =
        FixtureHelper.new_reaper_config(%{
          dataset_id: dataset.id,
          cadence: dataset.technical.cadence,
          sourceUrl: dataset.technical.sourceUrl,
          sourceFormat: dataset.technical.sourceFormat,
          schema: dataset.technical.schema,
          sourceQueryParams: dataset.technical.sourceQueryParams
        })

      expected = [
        %{"id" => "1", "name" => " Johnson", "pet" => " Spot"},
        %{"id" => "2", "name" => " Erin", "pet" => " Bella"},
        %{"id" => "3", "name" => " Ben", "pet" => " Max"}
      ]

      File.write!(@filename, ~s|1, Johnson, Spot\n2, Erin, Bella\n3, Ben, Max\n\n|)

      {:ok, actual} =
        {:file, @filename}
        |> Decoder.Csv.decode(reaper_config)

      assert Enum.into(actual, []) == expected
    end
  end
end
