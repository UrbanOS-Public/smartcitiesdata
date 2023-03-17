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
    test "discards CSV headers and is case insensitive" do
      ingestion =
        TDG.create_ingestion(%{
          id: "with-headers",
          sourceFormat: "csv",
          schema: [%{name: "iD"}, %{name: "name"}]
        })

      expected = [
        %{"iD" => "id", "name" => " something different"},
        %{"iD" => "1", "name" => " Woody"},
        %{"iD" => "2", "name" => " Buzz"}
      ]

      File.write!(@filename, ~s| ID , nAme\nid, something different\n1, Woody\n2, Buzz\n|)

      {:ok, actual} =
        {:file, @filename}
        |> Decoder.Csv.decode(ingestion)

      assert Enum.into(actual, []) == expected
    end

    test "converts CSV to map" do
      ingestion =
        TDG.create_ingestion(%{
          id: "cool",
          sourceFormat: "csv",
          schema: [%{name: "id"}, %{name: "name"}, %{name: "pet"}]
        })

      expected = [
        %{"id" => "1", "name" => " Johnson", "pet" => " Spot"},
        %{"id" => "2", "name" => " Erin", "pet" => " Bella"},
        %{"id" => "3", "name" => " Ben", "pet" => " Max"}
      ]

      File.write!(@filename, ~s|1, Johnson, Spot\n2, Erin, Bella\n3, Ben, Max\n\n|)

      {:ok, actual} =
        {:file, @filename}
        |> Decoder.Csv.decode(ingestion)

      assert Enum.into(actual, []) == expected
    end

    test "handles different sorting for CSV headers" do
      ingestion =
        TDG.create_ingestion(%{
          id: "with-headers",
          sourceFormat: "csv",
          schema: [%{name: "iD"}, %{name: "name"}]
        })

      expected = [
        %{"iD" => "1", "name" => "Buzz"}
      ]

      File.write!(@filename, ~s| name, id\n Buzz, 1\n|)

      {:ok, actual} =
        {:file, @filename}
        |> Decoder.Tsv.decode(ingestion)

      assert Enum.into(actual, []) == expected
    end
  end
end
