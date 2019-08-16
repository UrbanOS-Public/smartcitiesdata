defmodule ValkyrieTest do
  use ExUnit.Case
  import Checkov

  alias SmartCity.TestDataGenerator, as: TDG

  describe "standardize_data/1" do
    data_test "validates that #{value} is a valid #{type}" do
      dataset =
        TDG.create_dataset(
          id: "ds1",
          technical: %{
            schema: [
              %{name: field_name, type: type}
            ]
          }
        )

      payload = %{field_name => value}

      assert {:ok, payload} == Valkyrie.standardize_data(dataset, payload)

      where([
        [:field_name, :type, :value],
        ["name", "string", "some string"],
        ["age", "integer", 1],
        ["age", "long", 1],
        ["raining?", "boolean", true],
        ["raining?", "boolean", false],
        ["temperature", "float", 87.5],
        ["temperature", "double", 87.5]
      ])
    end

    data_test "transforms #{value} to a valid #{type}" do
      dataset =
        TDG.create_dataset(
          id: "ds1",
          technical: %{
            schema: [
              %{name: field_name, type: type}
            ]
          }
        )

      assert {:ok, %{field_name => transformed_value}} === Valkyrie.standardize_data(dataset, %{field_name => value})

      where([
        [:field_name, :type, :value, :transformed_value],
        ["age", "string", 123, "123"],
        ["age", "string", 123.5, "123.5"],
        ["age", "string", "  42 ", "42"],
        ["age", "integer", "21", 21],
        ["age", "long", "22", 22],
        ["age", "integer", "+25", 25],
        ["age", "integer", "-12", -12],
        ["raining?", "boolean", "true", true],
        ["raining?", "boolean", "false", false],
        ["temperature", "float", 101, 101.0],
        ["temperature", "float", "101.8", 101.8],
        ["temperature", "float", "+105.5", 105.5],
        ["temperature", "float", "-123.7", -123.7],
        ["temperature", "double", 87, 87.0],
        ["temperature", "double", "101.8", 101.8]
      ])
    end

    data_test "transforms #{value} to a valid #{type} with format #{format}" do
      dataset =
        TDG.create_dataset(
          id: "ds1",
          technical: %{
            schema: [
              %{name: "birthdate", format: format, type: type}
            ]
          }
        )

      payload = %{"birthdate" => value}

      expected = %{"birthdate" => Timex.parse!(value, format)}
      assert {:ok, expected} == Valkyrie.standardize_data(dataset, payload)

      where([
        [:type, :format, :value],
        ["date", "{YYYY}-{M}-{D}", "2019-05-27"],
        ["timestamp", "{YYYY}-{M}-{D} {h12}:{m}:{s} {AM}", "2019-05-12 08:12:11 PM"]
      ])
    end

    data_test "validates that #{value} with format #{format} is not a valid #{type}" do
      dataset =
        TDG.create_dataset(
          id: "ds1",
          technical: %{
            schema: [
              %{name: "birthdate", format: format, type: type}
            ]
          }
        )

      assert {:error, reason} == Valkyrie.standardize_data(dataset, %{"birthdate" => value})

      where([
        [:type, :format, :value, :reason],
        [
          "date",
          "{YYYY}-{M}-{D}",
          "2019/05/28",
          %{"birthdate" => {:invalid_date, "Expected `-`, but found `/` at line 1, column 5."}}
        ],
        [
          "timestamp",
          "{YYYY}-{M}-{D} {h12}:{m}:{s} {AM}",
          "2019-05-21 17:21:45",
          %{"birthdate" => {:invalid_timestamp, "Expected `hour between 1 and 12` at line 1, column 12."}}
        ]
      ])
    end

    data_test "validates that #{value} is a not a valid #{type}" do
      dataset =
        TDG.create_dataset(
          id: "ds1",
          technical: %{
            schema: [
              %{name: field_name, type: type}
            ]
          }
        )

      expected = {:error, %{field_name => reason}}
      assert expected == Valkyrie.standardize_data(dataset, %{field_name => value})

      where([
        [:field_name, :type, :value, :reason],
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
      dataset =
        TDG.create_dataset(
          id: "ds1",
          technical: %{
            schema: [
              %{name: field_name, type: type}
            ]
          }
        )

      payload = %{field_name => nil}
      assert {:ok, payload} == Valkyrie.standardize_data(dataset, payload)

      where([
        [:field_name, :type],
        ["name", "string"],
        ["age", "integer"]
      ])
    end

    test "transforms valid values in a map" do
      sub_schema = [
        %{name: "name", type: "string"},
        %{name: "age", type: "integer"},
        %{name: "human", type: "boolean"},
        %{name: "color", type: "string"},
        %{name: "luckyNumbers", type: "list", itemType: "integer"}
      ]

      dataset =
        TDG.create_dataset(
          id: "ds1",
          technical: %{
            schema: [
              %{name: "name", type: "string"},
              %{name: "spouse", type: "map", subSchema: sub_schema}
            ]
          }
        )

      payload = %{
        "name" => "Pete",
        "spouse" => %{
          "name" => "Shirley",
          "age" => "27",
          "human" => "true",
          "color" => nil,
          "luckyNumbers" => [1, "+2", 3]
        }
      }

      expected =
        {:ok,
         %{
           "name" => "Pete",
           "spouse" => %{
             "name" => "Shirley",
             "age" => 27,
             "human" => true,
             "color" => nil,
             "luckyNumbers" => [1, 2, 3]
           }
         }}

      assert expected == Valkyrie.standardize_data(dataset, payload)
    end

    test "validates that specified map is a map" do
      sub_schema = [
        %{name: "name", type: "string"}
      ]

      dataset =
        TDG.create_dataset(
          id: "ds1",
          technical: %{
            schema: [
              %{name: "name", type: "string"},
              %{name: "spouse", type: "map", subSchema: sub_schema}
            ]
          }
        )

      payload = %{"name" => "Pete", "spouse" => "Shirley"}

      expected = {:error, %{"spouse" => :invalid_map}}
      assert expected == Valkyrie.standardize_data(dataset, payload)
    end

    test "returns error that identifies nested field that fails" do
      sub_schema = [
        %{name: "name", type: "string"},
        %{name: "age", type: "integer"}
      ]

      dataset =
        TDG.create_dataset(
          id: "ds1",
          technical: %{
            schema: [
              %{name: "name", type: "string"},
              %{name: "spouse", type: "map", subSchema: sub_schema}
            ]
          }
        )

      payload = %{"name" => "Pete", "spouse" => %{"name" => "Shirley", "age" => "27.8"}}

      expected = {:error, %{"spouse" => %{"age" => :invalid_integer}}}
      assert expected == Valkyrie.standardize_data(dataset, payload)
    end

    test "returns error that identifies deeply nested field that fails" do
      sub_sub_schema = [
        %{name: "name", type: "string"}
      ]

      sub_schema = [
        %{name: "name", type: "string"},
        %{name: "child", type: "map", subSchema: sub_sub_schema}
      ]

      dataset =
        TDG.create_dataset(
          id: "ds1",
          technical: %{
            schema: [
              %{name: "name", type: "string"},
              %{name: "spouse", type: "map", subSchema: sub_schema}
            ]
          }
        )

      payload = %{"name" => "Pete", "spouse" => %{"name" => "Shirley", "child" => %{"name" => %{"stuff" => "13"}}}}

      expected = {:error, %{"spouse" => %{"child" => %{"name" => :invalid_string}}}}
      assert expected == Valkyrie.standardize_data(dataset, payload)
    end

    test "transforms valid values in lists" do
      sub_schema = [
        %{name: "name", type: "string"},
        %{name: "age", type: "integer"}
      ]

      dataset =
        TDG.create_dataset(
          id: "ds1",
          technical: %{
            schema: [
              %{name: "name", type: "string"},
              %{name: "luckyNumbers", type: "list", itemType: "integer"},
              %{name: "spouses", type: "list", itemType: "map", subSchema: sub_schema}
            ]
          }
        )

      payload = %{
        "name" => "Pete",
        "luckyNumbers" => [2, "3", 4],
        "spouses" => [
          %{"name" => "Shirley", "age" => 17},
          %{"name" => "Betty", "age" => "67"}
        ]
      }

      expected =
        {:ok,
         %{
           "name" => "Pete",
           "luckyNumbers" => [2, 3, 4],
           "spouses" => [
             %{"name" => "Shirley", "age" => 17},
             %{"name" => "Betty", "age" => 67}
           ]
         }}

      assert expected == Valkyrie.standardize_data(dataset, payload)
    end

    test "validates the provided list is a list" do
      dataset =
        TDG.create_dataset(
          id: "ds1",
          technical: %{
            schema: [
              %{name: "luckyNumbers", type: "list", itemType: "integer"}
            ]
          }
        )

      payload = %{"luckyNumbers" => "uh-huh"}

      expected = {:error, %{"luckyNumbers" => :invalid_list}}
      assert expected == Valkyrie.standardize_data(dataset, payload)
    end

    test "returns error that identifies wrong type in list" do
      dataset =
        TDG.create_dataset(
          id: "ds1",
          technical: %{
            schema: [
              %{name: "name", type: "string"},
              %{name: "luckyNumbers", type: "list", itemType: "integer"}
            ]
          }
        )

      payload = %{"name" => "Pete", "luckyNumbers" => [2, "three", 4]}

      expected = {:error, %{"luckyNumbers" => {:invalid_list, ":invalid_integer at index 1"}}}
      assert expected == Valkyrie.standardize_data(dataset, payload)
    end

    test "returns error that identifies invalid map in list" do
      sub_schema = [
        %{name: "name", type: "string"},
        %{name: "age", type: "integer"}
      ]

      dataset =
        TDG.create_dataset(
          id: "ds1",
          technical: %{
            schema: [
              %{name: "name", type: "string"},
              %{name: "spouses", type: "list", itemType: "map", subSchema: sub_schema}
            ]
          }
        )

      payload = %{
        "name" => "Pete",
        "spouses" => [
          %{"name" => "Shirley", "age" => 17},
          %{"name" => "George", "age" => "thirty"}
        ]
      }

      expected = {:error, %{"spouses" => {:invalid_list, "#{inspect(%{"age" => :invalid_integer})} at index 1"}}}
      assert expected == Valkyrie.standardize_data(dataset, payload)
    end

    test "returns error that identifies unknown schema type" do
      dataset =
        TDG.create_dataset(
          id: "ds1",
          technical: %{
            schema: [
              %{name: "geometry", type: "unknown"}
            ]
          }
        )

      payload = %{"geometry" => %{name: "some value"}}

      assert {:error, %{"geometry" => :invalid_type}} == Valkyrie.standardize_data(dataset, payload)
    end
  end

  describe "json is converted" do
    test "json is encoded to a string" do
      dataset =
        TDG.create_dataset(
          id: "ds1",
          technical: %{
            schema: [
              %{name: "geometry", type: "json"}
            ]
          }
        )

      payload = %{"geometry" => %{name: "different value"}}
      expected = %{"geometry" => "{\"name\":\"different value\"}"}

      assert {:ok, expected} == Valkyrie.standardize_data(dataset, payload)
    end

    test "invalid json" do
      dataset =
        TDG.create_dataset(
          id: "ds1",
          technical: %{
            schema: [
              %{name: "geometry", type: "json"}
            ]
          }
        )

      invalid_json_bitstring = <<0::1>>
      payload = %{"geometry" => invalid_json_bitstring}

      assert {:error, %{"geometry" => :invalid_json}} == Valkyrie.standardize_data(dataset, payload)
    end
  end
end
