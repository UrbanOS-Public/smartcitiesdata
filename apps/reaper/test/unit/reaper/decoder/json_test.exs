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

    [dataset: TDG.create_dataset(id: "ds1", technical: %{sourceFormat: "json"})]
  end

  describe "decode/2" do
    test "when given a JSON string it returns it as a List of Maps", %{dataset: dataset} do
      expected = [
        %{"id" => Faker.UUID.v4()}
      ]

      structure = expected |> Jason.encode!()
      File.write!(@filename, structure)

      {:ok, result} = Decoder.Json.decode({:file, @filename}, dataset)

      assert expected == result
    end

    test "when given a JSON object it returns it as a List of Maps", %{dataset: dataset} do
      structure = "{}"

      File.write!(@filename, structure)
      {:ok, result} = Decoder.Json.decode({:file, @filename}, dataset)

      assert is_list(result)
      assert is_map(hd(result))
    end

    test "bad json messages return error tuple", %{dataset: dataset} do
      body = "baaad json"
      File.write!(@filename, body)

      assert {:error, body, Jason.DecodeError.exception(data: body, position: 0)} ==
               Reaper.Decoder.Json.decode({:file, @filename}, dataset)
    end

    test "Decodes json data using the top level selector key" do
      dataset_with_selector =
        TDG.create_dataset(id: "ds1", technical: %{topLevelSelector: "$.data", sourceFormat: "json"})

      body = %{data: [%{name: "Bob"}, %{name: "Fred"}], type: "Madness"} |> Jason.encode!()
      expected = [%{"name" => "Bob"}, %{"name" => "Fred"}]
      File.write!(@filename, body)

      {:ok, result} = Decoder.Json.decode({:file, @filename}, dataset_with_selector)

      assert is_list(result)
      assert is_map(hd(result))

      assert result == expected
    end

    test "Decodes json array using the top level selector key" do
      dataset_with_selector =
        TDG.create_dataset(id: "ds1", technical: %{topLevelSelector: "$.[*].data", sourceFormat: "json"})

      body =
        [
          %{data: [%{name: "Bob"}, %{name: "Fred"}], type: "Madness"},
          %{data: [%{name: "Rob"}, %{name: "Gred"}], type: "Derp"}
        ]
        |> Jason.encode!()

      expected = [%{"name" => "Bob"}, %{"name" => "Fred"}, %{"name" => "Rob"}, %{"name" => "Gred"}]
      File.write!(@filename, body)

      {:ok, result} = Decoder.Json.decode({:file, @filename}, dataset_with_selector)

      assert is_list(result)
      assert is_map(hd(result))

      assert result == expected
    end

    test "bad topLevelSelector returns error tuple" do
      dataset_with_selector =
        TDG.create_dataset(id: "ds1", technical: %{topLevelSelector: "$.data[XX]", sourceFormat: "json"})

      body = %{data: [%{name: "Bob"}, %{name: "Fred"}], type: "Madness"} |> Jason.encode!()
      File.write!(@filename, body)

      assert {:error, ^body, %Jaxon.ParseError{}} =
               Reaper.Decoder.Json.decode({:file, @filename}, dataset_with_selector)
    end

    test "bad json with topLevelSelector returns error tuple" do
      dataset_with_selector =
        TDG.create_dataset(id: "ds1", technical: %{topLevelSelector: "$.data", sourceFormat: "json"})

      bad_body = "{\"data\":[{\"name\":QuotelessBob\"},{\"name\":\"Fred\"}],\"type\":\"Madness\"}"
      File.write!(@filename, bad_body)

      assert {:error, ^bad_body, %Jaxon.ParseError{}} =
               Reaper.Decoder.Json.decode({:file, @filename}, dataset_with_selector)
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
