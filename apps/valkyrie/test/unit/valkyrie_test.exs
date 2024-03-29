defmodule ValkyrieTest do
  use ExUnit.Case
  import Checkov

  alias SmartCity.TestDataGenerator, as: TDG
  alias Jason

  describe "standardize_data/1" do
    data_test "validates that #{value} is a valid #{type}" do
      dataset =
        TDG.create_dataset(
          id: "ds1",
          technical: %{
            schema: [
              %{name: field_name, type: type, ingestion_field_selector: selector}
            ]
          }
        )

      payload = %{selector => value}
      expected = %{field_name => value}

      assert {:ok, expected} == Valkyrie.standardize_data(dataset, payload)

      where([
        [:field_name, :selector, :type, :value],
        ["name", "name", "string", "some string"],
        ["name", "selector", "string", "some string"],
        ["age", "age", "integer", 1],
        ["age", "age", "long", 1],
        ["raining?", "raining?", "boolean", true],
        ["raining?", "raining?", "boolean", false],
        ["temperature", "temperature", "float", 87.5],
        ["temperature", "temperature", "double", 87.5]
      ])
    end

    data_test "transforms #{value} to a valid #{type}" do
      dataset =
        TDG.create_dataset(
          id: "ds1",
          technical: %{
            schema: [
              %{name: field_name, type: type, ingestion_field_selector: selector}
            ]
          }
        )

      assert {:ok, %{field_name => transformed_value}} === Valkyrie.standardize_data(dataset, %{selector => value})

      where([
        [:field_name, :selector, :type, :value, :transformed_value],
        ["age", "age", "string", 123, "123"],
        ["age", "selector", "string", 123, "123"],
        ["age", "age", "string", 123.5, "123.5"],
        ["age", "age", "string", "  42 ", "42"],
        ["age", "age", "integer", "21", 21],
        ["age", "age", "long", "22", 22],
        ["age", "age", "integer", "+25", 25],
        ["age", "age", "integer", "-12", -12],
        ["raining?", "raining?", "boolean", "true", true],
        ["raining?", "raining?", "boolean", "false", false],
        ["temperature", "temperature", "float", 101, 101.0],
        ["temperature", "temperature", "float", "101.8", 101.8],
        ["temperature", "temperature", "float", "+105.5", 105.5],
        ["temperature", "temperature", "float", "-123.7", -123.7],
        ["temperature", "temperature", "double", 87, 87.0],
        ["temperature", "temperature", "double", "101.8", 101.8]
      ])
    end

    data_test "transforms #{value} to a valid #{type} with format #{format}" do
      dataset =
        TDG.create_dataset(
          id: "ds1",
          technical: %{
            schema: [
              %{name: "birthdate", format: format, type: type, ingestion_field_selector: "birthdate"}
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
              %{name: "birthdate", format: format, type: type, ingestion_field_selector: "birthdate"}
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
              %{name: field_name, type: type, ingestion_field_selector: selector}
            ]
          }
        )

      expected = {:error, %{field_name => reason}}
      assert expected == Valkyrie.standardize_data(dataset, %{selector => value})

      where([
        [:field_name, :selector, :type, :value, :reason],
        ["age", "age", "integer", "abc", :invalid_integer],
        ["age", "age", "integer", "34.5", :invalid_integer],
        ["age", "age", "long", "abc", :invalid_long],
        ["age", "age", "long", "34.5", :invalid_long],
        ["raining?", "raining?", "boolean", "nope", :invalid_boolean],
        ["temperature", "temperature", "float", "howdy!", :invalid_float],
        ["temperature", "temperature", "double", "howdy!", :invalid_double],
        ["temperature", "temperature", "double", "123..7", :invalid_double]
      ])
    end

    data_test "validates that nil is a valid #{type}" do
      dataset =
        TDG.create_dataset(
          id: "ds1",
          technical: %{
            schema: [
              %{name: field_name, type: type, ingestion_field_selector: selector}
            ]
          }
        )

      payload = %{selector => nil}
      assert {:ok, payload} == Valkyrie.standardize_data(dataset, payload)

      where([
        [:field_name, :selector, :type],
        ["name", "name", "string"],
        ["age", "age", "integer"]
      ])
    end

    data_test "validates that an empty string is a valid #{type}" do
      dataset =
        TDG.create_dataset(
          id: "ds1",
          technical: %{
            schema: [
              %{name: field_name, type: type, ingestion_field_selector: selector}
            ]
          }
        )

      assert {:ok, %{selector => nil}} == Valkyrie.standardize_data(dataset, %{selector => ""})

      where([
        [:field_name, :selector, :type],
        ["age", "age", "integer"],
        ["numOfLives", "numOfLives", "long"],
        ["weight", "weight", "double"],
        ["height", "height", "float"],
        ["isCool", "isCool", "boolean"],
        ["dob", "dob", "timestamp"]
      ])
    end

    test "an empty string of type string should not be converted to nil" do
      dataset =
        TDG.create_dataset(
          id: "ds1",
          technical: %{
            schema: [
              %{name: "empty_string", type: "string", ingestion_field_selector: "empty_string"}
            ]
          }
        )

      assert {:ok, %{"empty_string" => ""}} == Valkyrie.standardize_data(dataset, %{"empty_string" => ""})
    end

    test "transforms valid values in a map" do
      sub_schema = [
        %{name: "name", type: "string", ingestion_field_selector: "name"},
        %{name: "age", type: "integer", ingestion_field_selector: "age"},
        %{name: "human", type: "boolean", ingestion_field_selector: "human"},
        %{name: "color", type: "string", ingestion_field_selector: "color"},
        %{name: "luckyNumbers", type: "list", itemType: "integer", ingestion_field_selector: "luckyNumbers"}
      ]

      dataset =
        TDG.create_dataset(
          id: "ds1",
          technical: %{
            schema: [
              %{name: "name", type: "string", ingestion_field_selector: "name"},
              %{name: "spouse", type: "map", subSchema: sub_schema, ingestion_field_selector: "spouse"}
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
        %{name: "name", type: "string", ingestion_field_selector: "name"}
      ]

      dataset =
        TDG.create_dataset(
          id: "ds1",
          technical: %{
            schema: [
              %{name: "name", type: "string", ingestion_field_selector: "name"},
              %{name: "spouse", type: "map", subSchema: sub_schema, ingestion_field_selector: "spouse"}
            ]
          }
        )

      payload = %{"name" => "Pete", "spouse" => "Shirley"}

      expected = {:error, %{"spouse" => :invalid_map}}
      assert expected == Valkyrie.standardize_data(dataset, payload)
    end

    test "returns error that identifies nested field that fails" do
      sub_schema = [
        %{name: "name", type: "string", ingestion_field_selector: "name"},
        %{name: "age", type: "integer", ingestion_field_selector: "age"}
      ]

      dataset =
        TDG.create_dataset(
          id: "ds1",
          technical: %{
            schema: [
              %{name: "name", type: "string", ingestion_field_selector: "name"},
              %{name: "spouse", type: "map", subSchema: sub_schema, ingestion_field_selector: "spouse"}
            ]
          }
        )

      payload = %{"name" => "Pete", "spouse" => %{"name" => "Shirley", "age" => "27.8"}}

      expected = {:error, %{"spouse" => %{"age" => :invalid_integer}}}
      assert expected == Valkyrie.standardize_data(dataset, payload)
    end

    test "returns error that identifies deeply nested field that fails" do
      sub_sub_schema = [
        %{name: "name", type: "string", ingestion_field_selector: "name"}
      ]

      sub_schema = [
        %{name: "name", type: "string", ingestion_field_selector: "name"},
        %{name: "child", type: "map", subSchema: sub_sub_schema, ingestion_field_selector: "child"}
      ]

      dataset =
        TDG.create_dataset(
          id: "ds1",
          technical: %{
            schema: [
              %{name: "name", type: "string", ingestion_field_selector: "name"},
              %{name: "spouse", type: "map", subSchema: sub_schema, ingestion_field_selector: "spouse"}
            ]
          }
        )

      payload = %{"name" => "Pete", "spouse" => %{"name" => "Shirley", "child" => %{"name" => %{"stuff" => "13"}}}}

      expected = {:error, %{"spouse" => %{"child" => %{"name" => :invalid_string}}}}
      assert expected == Valkyrie.standardize_data(dataset, payload)
    end

    test "transforms valid values in lists" do
      sub_schema = [
        %{name: "name", type: "string", ingestion_field_selector: "name"},
        %{name: "age", type: "integer", ingestion_field_selector: "age"}
      ]

      dataset =
        TDG.create_dataset(
          id: "ds1",
          technical: %{
            schema: [
              %{name: "name", type: "string", ingestion_field_selector: "name"},
              %{name: "luckyNumbers", type: "list", itemType: "integer", ingestion_field_selector: "luckyNumbers"},
              %{
                name: "spouses",
                type: "list",
                itemType: "map",
                subSchema: sub_schema,
                ingestion_field_selector: "spouses"
              }
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

    test "transforms valid values in deeply nested lists" do
      second_sub_schema = [
        %{name: "second_list_name", type: "list", itemType: "string", ingestion_field_selector: "name"}
      ]

      first_sub_schema = [
        %{
          name: "first_list_name",
          type: "list",
          itemType: "list",
          subSchema: second_sub_schema,
          ingestion_field_selector: "name"
        }
      ]

      dataset =
        TDG.create_dataset(
          id: "ds1",
          technical: %{
            schema: [
              %{name: "name", type: "string", ingestion_field_selector: "name"},
              %{
                name: "luckyNumbers",
                type: "list",
                itemType: "list",
                subSchema: first_sub_schema,
                ingestion_field_selector: "luckyNumbers"
              }
            ]
          }
        )

      payload = %{
        "name" => "Pete",
        "luckyNumbers" => [[["1", 1, "foo"]]]
      }

      expected =
        {:ok,
         %{
           "name" => "Pete",
           "luckyNumbers" => [[["1", "1", "foo"]]]
         }}

      assert expected == Valkyrie.standardize_data(dataset, payload)
    end

    test "transforms valid values in combined nested lists and maps" do
      fourth_sub_schema = [
        %{name: "inner_field", type: "string", ingestion_field_selector: "inner_field"}
      ]

      third_sub_schema = [
        %{name: "fieldA", type: "string", ingestion_field_selector: "fieldA"},
        %{
          name: "fieldB",
          type: "list",
          itemType: "map",
          subSchema: fourth_sub_schema,
          ingestion_field_selector: "fieldB"
        }
      ]

      second_sub_schema = [
        %{
          name: "second_list_name",
          type: "list",
          itemType: "map",
          subSchema: third_sub_schema,
          ingestion_field_selector: "second_list_name"
        }
      ]

      first_sub_schema = [
        %{
          name: "first_list_name",
          type: "list",
          itemType: "list",
          subSchema: second_sub_schema,
          ingestion_field_selector: "first_list_name"
        }
      ]

      dataset =
        TDG.create_dataset(
          id: "ds1",
          technical: %{
            schema: [
              %{name: "name", type: "string", ingestion_field_selector: "name"},
              %{
                name: "luckyNumbers",
                type: "list",
                itemType: "list",
                subSchema: first_sub_schema,
                subingestion_field_selector: "luckyNumbers",
                ingestion_field_selector: "luckyNumbers"
              }
            ]
          }
        )

      payload = %{
        "name" => "Pete",
        "luckyNumbers" => [
          [
            [
              %{
                "fieldA" => 1,
                "fieldB" => [
                  %{"inner_field" => 1},
                  %{"inner_field" => "1"}
                ]
              },
              %{
                "fieldA" => "1",
                "fieldB" => [
                  %{"inner_field" => 1},
                  %{"inner_field" => "1"}
                ]
              }
            ]
          ]
        ]
      }

      expected =
        {:ok,
         %{
           "name" => "Pete",
           "luckyNumbers" => [
             [
               [
                 %{
                   "fieldA" => "1",
                   "fieldB" => [
                     %{"inner_field" => "1"},
                     %{"inner_field" => "1"}
                   ]
                 },
                 %{
                   "fieldA" => "1",
                   "fieldB" => [
                     %{"inner_field" => "1"},
                     %{"inner_field" => "1"}
                   ]
                 }
               ]
             ]
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
              %{name: "luckyNumbers", type: "list", itemType: "integer", ingestion_field_selector: "luckyNumbers"}
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
              %{name: "name", type: "string", ingestion_field_selector: "name"},
              %{name: "luckyNumbers", type: "list", itemType: "integer", ingestion_field_selector: "luckyNumbers"}
            ]
          }
        )

      payload = %{"name" => "Pete", "luckyNumbers" => [2, "three", 4]}

      expected = {:error, %{"luckyNumbers" => {:invalid_list, ":invalid_integer at index 1"}}}
      assert expected == Valkyrie.standardize_data(dataset, payload)
    end

    test "returns error that identifies invalid map in list" do
      sub_schema = [
        %{name: "name", type: "string", ingestion_field_selector: "name"},
        %{name: "age", type: "integer", ingestion_field_selector: "age"}
      ]

      dataset =
        TDG.create_dataset(
          id: "ds1",
          technical: %{
            schema: [
              %{name: "name", type: "string", ingestion_field_selector: "name"},
              %{
                name: "spouses",
                type: "list",
                itemType: "map",
                subSchema: sub_schema,
                ingestion_field_selector: "spouses"
              }
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

      expected = {:error, %{"spouses" => %{"age" => :invalid_integer}}}
      assert expected == Valkyrie.standardize_data(dataset, payload)
    end

    test "returns error that identifies unknown schema type" do
      dataset =
        TDG.create_dataset(
          id: "ds1",
          technical: %{
            schema: [
              %{name: "geometry", type: "unknown", ingestion_field_selector: "geometry"}
            ]
          }
        )

      payload = %{"geometry" => %{name: "some value"}}

      assert {:error, %{"geometry" => :invalid_type}} == Valkyrie.standardize_data(dataset, payload)
    end

    test "returns error if cannot parse list of lists" do
      sub_schema = [
        %{name: "doesntMatter", type: "list", itemType: "integer", ingestion_field_selector: "doesntMatter"}
      ]

      dataset =
        TDG.create_dataset(
          id: "ds1",
          technical: %{
            schema: [
              %{name: "name", type: "string", ingestion_field_selector: "name"},
              %{
                name: "luckyNumbers",
                type: "list",
                itemType: "list",
                subSchema: sub_schema,
                ingestion_field_selector: "luckyNumbers"
              }
            ]
          }
        )

      payload = %{
        "name" => "Pete",
        "luckyNumbers" => [[-83.01347, 42.38928], [-83.01347, 42.38928], [-83.01347, 42.38928]]
      }

      result = Valkyrie.standardize_data(dataset, payload)

      assert {:error, %{"luckyNumbers" => %{unhandled_standardization_exception: %FunctionClauseError{}}}} = result
    end

    test "can parse list of lists" do
      sub_schema = [
        %{name: "doesntMatter", type: "list", itemType: "float", ingestion_field_selector: "doesntMatter"}
      ]

      dataset =
        TDG.create_dataset(
          id: "ds1",
          technical: %{
            schema: [
              %{name: "name", type: "string", ingestion_field_selector: "name"},
              %{
                name: "luckyNumbers",
                type: "list",
                itemType: "list",
                subSchema: sub_schema,
                ingestion_field_selector: "luckyNumbers"
              }
            ]
          }
        )

      payload = %{
        "name" => "Pete",
        "luckyNumbers" => [[-83.01347, 42.38928], [-83.01347, 42.38928], [-83.01347, 42.38928]]
      }

      expected =
        {:ok,
         %{
           "name" => "Pete",
           "luckyNumbers" => [[-83.01347, 42.38928], [-83.01347, 42.38928], [-83.01347, 42.38928]]
         }}

      assert expected == Valkyrie.standardize_data(dataset, payload)
    end
  end

  describe "json is converted" do
    test "json is encoded to a string" do
      dataset =
        TDG.create_dataset(
          id: "ds1",
          technical: %{
            schema: [
              %{name: "geometry", type: "json", ingestion_field_selector: "geometry"}
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
              %{name: "geometry", type: "json", ingestion_field_selector: "geometry"}
            ]
          }
        )

      invalid_json_bitstring = <<0::1>>

      payload = %{"geometry" => invalid_json_bitstring}

      assert {:error, %{"geometry" => :invalid_json}} == Valkyrie.standardize_data(dataset, payload)
    end
  end
end
