defmodule Reaper.Decoder.JsonTest do
  use ExUnit.Case
  use Placebo
  alias Reaper.Decoder
  alias SmartCity.TestDataGenerator, as: TDG
  import Checkov

  @filename "#{__MODULE__}_temp_file"

  setup do
    on_exit(fn ->
      File.rm(@filename)
    end)

    [ingestion: TDG.create_ingestion(%{id: "ds1", sourceFormat: "json", topLevelSelector: nil})]
  end

  describe "decode/2" do
    test "when given a JSON string it returns it as a List of Maps", %{ingestion: ingestion} do
      expected = [
        %{"id" => Faker.UUID.v4()}
      ]

      structure = expected |> Jason.encode!()
      File.write!(@filename, structure)

      {:ok, result} = Decoder.Json.decode({:file, @filename}, ingestion)

      assert expected == result
    end

    test "when given a JSON object it returns it as a List of Maps", %{ingestion: ingestion} do
      structure = "{}"

      File.write!(@filename, structure)
      {:ok, result} = Decoder.Json.decode({:file, @filename}, ingestion)

      assert is_list(result)
      assert is_map(hd(result))
    end

    test "bad json messages return error tuple", %{ingestion: ingestion} do
      body = "baaad json"
      File.write!(@filename, body)

      assert {:error, body, Jason.DecodeError.exception(data: body, position: 0)} ==
               Reaper.Decoder.Json.decode({:file, @filename}, ingestion)
    end

    test "Decodes json data using the top level selector key" do
      ingestion_with_selector =
        TDG.create_ingestion(%{id: "ds1", topLevelSelector: "$.data", sourceFormat: "json"})

      body = %{data: [%{name: "Bob"}, %{name: "Fred"}], type: "Madness"} |> Jason.encode!()
      expected = [%{"name" => "Bob"}, %{"name" => "Fred"}]
      File.write!(@filename, body)

      {:ok, result} = Decoder.Json.decode({:file, @filename}, ingestion_with_selector)

      assert is_list(result)
      assert is_map(hd(result))

      assert result == expected
    end

    data_test "json decoder handles empty arrays with topLevelSelector: #{selector}" do
      ingestion_with_selector = TDG.create_ingestion(%{sourceFormat: "json", topLevelSelector: selector})

      body = body |> Jason.encode!()
      File.write!(@filename, body)

      {:ok, result} = Decoder.Json.decode({:file, @filename}, ingestion_with_selector)

      assert result == []

      where([
        [:body, :selector],
        [%{data: []}, "$.data[*]"],
        [%{data: %{nested_data: []}}, "$.data.nested_data[*]"],
        [%{data: [%{nested_data: []}]}, "$.data[*].nested_data[*]"]
      ])
    end

    test "Decodes json array using the top level selector key" do
      ingestion_with_selector =
        TDG.create_ingestion(%{id: "ds1", topLevelSelector: "$.[*].data", sourceFormat: "json"})

      body =
        [
          %{data: [%{name: "Bob"}, %{name: "Fred"}], type: "Madness"},
          %{data: [%{name: "Rob"}, %{name: "Gred"}], type: "Derp"}
        ]
        |> Jason.encode!()

      expected = [%{"name" => "Bob"}, %{"name" => "Fred"}, %{"name" => "Rob"}, %{"name" => "Gred"}]
      File.write!(@filename, body)

      {:ok, result} = Decoder.Json.decode({:file, @filename}, ingestion_with_selector)

      assert is_list(result)
      assert is_map(hd(result))

      assert result == expected
    end

    test "bad topLevelSelector returns error tuple" do
      ingestion_with_selector =
        TDG.create_ingestion(%{id: "ds1", topLevelSelector: "$.data[XX]", sourceFormat: "json"})

      body = %{data: [%{name: "Bob"}, %{name: "Fred"}], type: "Madness"} |> Jason.encode!()
      File.write!(@filename, body)

      assert {:error, ^body, %Jaxon.ParseError{}} =
               Reaper.Decoder.Json.decode({:file, @filename}, ingestion_with_selector)
    end

    test "bad json with topLevelSelector returns error tuple" do
      ingestion_with_selector =
        TDG.create_ingestion(%{id: "ds1", topLevelSelector: "$.data", sourceFormat: "json"})

      bad_body = "{\"data\":[{\"name\":QuotelessBob\"},{\"name\":\"Fred\"}],\"type\":\"Madness\"}"
      File.write!(@filename, bad_body)

      assert {:error, ^bad_body, %Jaxon.ParseError{}} =
               Reaper.Decoder.Json.decode({:file, @filename}, ingestion_with_selector)
    end
  end

  describe "handle/1" do
    data_test "source_format of '#{format}' returns #{result}" do
      assert result == Decoder.Json.handle?(format)

      where([
        [:format, :result],
        ["application/json", true],
        ["json", false],
        ["csv", false],
        ["", false],
        [nil, false]
      ])
    end
  end
end
