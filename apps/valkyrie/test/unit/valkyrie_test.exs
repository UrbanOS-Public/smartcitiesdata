defmodule ValkyrieTest do
  use ExUnit.Case
  import Checkov

  alias SmartCity.TestDataGenerator, as: TDG
  alias Valkyrie.Dataset
  alias SmartCity.Data

  describe "validate_data/1" do
    data_test "validates that #{value} is a valid #{type}" do
      dataset = %Dataset{
        schema: [
          %{name: field_name, type: type}
        ]
      }

      data = TDG.create_data(payload: %{field_name => value})

      assert :ok == Valkyrie.validate_data(dataset, data)

      where([
        [:field_name, :type, :value],
        ["name", "string", "some string"],
        ["age", "integer", 1],
        ["age", "integer", "21"],
        ["age", "long", 1],
        ["age", "long", "22"],
        ["age", "integer", "+25"],
        ["age", "integer", "-12"],
        ["raining?", "boolean", true],
        ["raining?", "boolean", false],
        ["raining?", "boolean", "true"],
        ["raining?", "boolean", "false"],
        ["temperature", "float", 87.5],
        ["temperature", "float", 101],
        ["temperature", "float", "101.8"],
        ["temperature", "float", "+105.5"],
        ["temperature", "float", "-123.7"],
        ["temperature", "double", 87.5],
        ["temperature", "double", "101.8"]
      ])
    end

    data_test "validates #{type} #{value} with format #{format}" do
      dataset = %Dataset{
        schema: [
          %{name: "birthdate", format: format, type: type}
        ]
      }

      data = TDG.create_data(payload: %{"birthdate" => value})

      assert result == Valkyrie.validate_data(dataset, data)

      where([
        [:type, :format, :value, :result],
        ["date", "{YYYY}-{M}-{D}", "2019-05-27", :ok],
        ["timestamp", "{YYYY}-{M}-{D} {h12}:{m}:{s} {AM}", "2019-05-12 08:12:11 PM", :ok],
        [
          "date",
          "{YYYY}-{M}-{D}",
          "2019/05/28",
          {:error, %{"birthdate" => {:invalid_date, "Expected `-`, but found `/` at line 1, column 5."}}}
        ],
        [
          "timestamp",
          "{YYYY}-{M}-{D} {h12}:{m}:{s} {AM}",
          "2019-05-21 17:21:45",
          {:error, %{"birthdate" => {:invalid_timestamp, "Expected `hour between 1 and 12` at line 1, column 12."}}}
        ]
      ])
    end

    data_test "validates that #{value} is a not a valid #{type}" do
      dataset = %Dataset{
        schema: [
          %{name: field_name, type: type}
        ]
      }

      data = TDG.create_data(payload: %{field_name => value})

      expected = {:error, %{field_name => reason}}
      assert expected == Valkyrie.validate_data(dataset, data)

      where([
        [:field_name, :type, :value, :reason],
        ["name", "string", 1, :invalid_string],
        ["age", "integer", "abc", :invalid_integer],
        ["age", "integer", "34.5", :invalid_integer],
        ["age", "long", "abc", :invalid_long],
        ["age", "long", "34.5", :invalid_long],
        ["raining?", "boolean", "nope", :invalid_boolean],
        ["temperature", "float", "howdy!", :invalid_float],
        ["temperature", "double", "howdy!", :invalid_double],
        ["temperature", "double", "123..7", :invalid_double]
      ])
    end

    data_test "validates that nil is a valid #{type}" do
      dataset = %Dataset{
        schema: [
          %{name: field_name, type: type}
        ]
      }

      data = TDG.create_data(payload: %{field_name => nil})

      assert :ok == Valkyrie.validate_data(dataset, data)

      where([
        [:field_name, :type],
        ["name", "string"],
        ["age", "integer"]
      ])
    end

    test "returns :ok for a valid map" do
      sub_schema = [
        %{name: "name", type: "string"},
        %{name: "age", type: "integer"}
      ]

      dataset = %Dataset{
        schema: [
          %{name: "name", type: "string"},
          %{name: "spouse", type: "map", subSchema: sub_schema}
        ]
      }

      data = TDG.create_data(payload: %{"name" => "Pete", "spouse" => %{"name" => "Shirley", "age" => "27"}})

      assert :ok == Valkyrie.validate_data(dataset, data)
    end

    test "return error that identifies nested field that fails" do
      sub_schema = [
        %{name: "name", type: "string"},
        %{name: "age", type: "integer"}
      ]

      dataset = %Dataset{
        schema: [
          %{name: "name", type: "string"},
          %{name: "spouse", type: "map", subSchema: sub_schema}
        ]
      }

      data = TDG.create_data(payload: %{"name" => "Pete", "spouse" => %{"name" => "Shirley", "age" => "27.8"}})

      expected = {:error, %{"spouse" => %{"age" => :invalid_integer}}}
      assert expected == Valkyrie.validate_data(dataset, data)
    end
  end
end
