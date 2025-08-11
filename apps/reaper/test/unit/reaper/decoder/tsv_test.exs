defmodule Reaper.Decoder.TsvTest do
  use ExUnit.Case
  alias Reaper.Decoder
  alias SmartCity.TestDataGenerator, as: TDG

  @filename "#{__MODULE__}_te\mp_file"

  setup do
    on_exit(fn ->
      File.rm(@filename)
    end)

    :ok
  end

  describe "decode/2" do
    test "discards TSV headers and is case insensitive" do
      ingestion =
        TDG.create_ingestion(%{
          id: "with-headers",
          sourceFormat: "tsv",
          schema: [%{name: "iD"}, %{name: "name"}]
        })

      expected = [
        %{"iD" => "id", "name" => " something different"},
        %{"iD" => "1", "name" => " Woody"},
        %{"iD" => "2", "name" => " Buzz"}
      ]

      File.write!(@filename, ~s| ID \t nAme\nid\t something different\n1\t Woody\n2\t Buzz\n|)

      {:ok, actual} =
        {:file, @filename}
        |> Decoder.Tsv.decode(ingestion)

      assert Enum.into(actual, []) == expected
    end

    test "converts TSV to map" do
      ingestion =
        TDG.create_ingestion(%{
          id: "cool",
          sourceFormat: "tsv",
          schema: [%{name: "id"}, %{name: "name"}, %{name: "pet"}]
        })

      expected = [
        %{"id" => "1", "name" => " Johnson", "pet" => " Spot"},
        %{"id" => "2", "name" => " Erin", "pet" => " Bella"},
        %{"id" => "3", "name" => " Ben", "pet" => " Max"}
      ]

      File.write!(@filename, ~s|1\t Johnson\t Spot\n2\t Erin\t Bella\n3\t Ben\t Max\n\n|)

      {:ok, actual} =
        {:file, @filename}
        |> Decoder.Tsv.decode(ingestion)

      assert Enum.into(actual, []) == expected
    end
  end
end
