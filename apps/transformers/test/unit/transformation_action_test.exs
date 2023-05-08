defmodule TransformationActionTest do
  use ExUnit.Case

  import Checkov

  alias Transformers
  alias SmartCity.TestDataGenerator, as: TDG

  describe "Construct" do
    test "should construct transformation" do
      transformation1 =
        TDG.create_transformation(%{
          name: "sample",
          type: "add",
          parameters: %{
            "condition" => "false",
            "addends" => "5, 9",
            "targetField" => "parent.add"
          },
          sequence: 0
        })

      transformation2 =
        TDG.create_transformation(%{
          name: "sample",
          type: "concatenation",
          parameters: %{
            "condition" => "false",
            "sourceFields" => "one, parent.child.two",
            "separator" => ", ",
            "targetField" => "concat"
          },
          sequence: 1
        })

      operations =
        [transformation1, transformation2]
        |> Transformers.construct()

      assert length(operations) == 2
    end

    test "should error" do
      [error: reason] = Transformers.construct([%{}])

      assert reason == "Map provided is not a valid transformation"
    end
  end

  describe "Validate" do
    test "should validate transformation" do
      transformation1 =
        TDG.create_transformation(%{
          name: "sample",
          type: "add",
          parameters: %{
            "condition" => "false",
            "addends" => "5, 9",
            "targetField" => "parent.add"
          },
          sequence: 0
        })

      transformation2 =
        TDG.create_transformation(%{
          name: "sample",
          type: "concatenation",
          parameters: %{
            "condition" => "false",
            "sourceFields" => "one, parent.child.two",
            "separator" => ", ",
            "targetField" => "concat"
          },
          sequence: 1
        })

      assert [ok: "Transformation valid.", ok: "Transformation valid."] ==
               [transformation1, transformation2]
               |> Transformers.validate()
    end

    test "should error" do
      [error: reason] = Transformers.validate([%{}])

      assert reason == "Map provided is not a valid transformation"
    end
  end

  describe "Perform" do
    test "should perform operations" do
      transformation1 =
        TDG.create_transformation(%{
          name: "sample",
          type: "add",
          parameters: %{
            "condition" => "false",
            "addends" => "5, 9",
            "targetField" => "parent.add"
          },
          sequence: 0
        })

      transformation2 =
        TDG.create_transformation(%{
          name: "sample",
          type: "concatenation",
          parameters: %{
            "condition" => "false",
            "sourceFields" => "one, parent.child.two",
            "separator" => ", ",
            "targetField" => "concat"
          },
          sequence: 1
        })

      operations =
        [transformation1, transformation2]
        |> Transformers.construct()

      initial_payload = %{
        "one" => "something",
        "parent" => %{
          "child" => %{
            "two" => "else"
          }
        }
      }

      {:ok, resulting_payload} = Transformers.perform(operations, initial_payload)

      assert resulting_payload == %{
               "one" => "something",
               "parent" => %{
                 "add" => 14,
                 "child" => %{
                   "two" => "else"
                 }
               },
               "concat" => "something, else"
             }
    end

    test "should error out and give reason" do
      transformation1 =
        TDG.create_transformation(%{
          name: "sample",
          type: "add",
          parameters: %{
            "condition" => "false",
            "addends" => "5, 9",
            "targetField" => "parent.add"
          },
          sequence: 0
        })

      transformation2 =
        TDG.create_transformation(%{
          name: "sample",
          type: "concatenation",
          parameters: %{
            "condition" => "false",
            "sourceFields" => "INVALID, parent.child.two",
            "separator" => ", ",
            "targetField" => "concat"
          },
          sequence: 1
        })

      operations =
        [transformation1, transformation2]
        |> Transformers.construct()

      initial_payload = %{
        "one" => "something",
        "parent" => %{
          "child" => %{
            "two" => "else"
          }
        }
      }

      {:error, reason} = Transformers.perform(operations, initial_payload)

      assert reason == "Missing field in payload: [INVALID]"
    end

    data_test "should flatten and split correctly: #{test_name}" do
      transformation1 =
        TDG.create_transformation(%{
          name: "sample",
          type: "add",
          parameters: %{
            "condition" => "false",
            "addends" => addends,
            "targetField" => "target_field"
          },
          sequence: 0
        })

      operations =
        [transformation1]
        |> Transformers.construct()

      {:ok, resulting_payload} = Transformers.perform(operations, payload)

      expected_payload = Map.put(payload, "target_field", 7)

      assert expected_payload == resulting_payload

      where([
        [:test_name, :payload, :addends],
        ["single level", %{"foo" => 4, "bar" => 3}, "foo, bar"],
        ["1 level map child", %{"parent" => %{"foo" => 4}, "bar" => 3}, "parent.foo, bar"],
        [
          "2 level map child",
          %{"parent" => %{"child" => %{"foo" => 4}}, "bar" => 3},
          "parent.child.foo, bar"
        ],
        [
          "both are inside map with doubled value",
          %{"parent" => %{"child" => %{"foo" => 4}, "bar" => 3}, "bar" => 34542},
          "parent.child.foo, parent.bar"
        ],
        ["get first value of list", %{"parent" => [4, 2_438_509], "bar" => 3}, "parent[0], bar"],
        [
          "fully nested lists",
          %{"list" => [[135_893, 4], [23425, 2842]], "list2" => [[3324, 54353], [3_452_435, 3]]},
          "list[0][1], list2[1][1]"
        ],
        [
          "nested lists within maps",
          %{"parent" => %{"child" => %{"list" => [[4, 13243], [342_134, 3]]}}},
          "parent.child.list[0][0], parent.child.list[1][1]"
        ],
        [
          "multiple objects in list",
          %{
            "list" => [[135_893, 4], [23425, 2842]],
            "list2" => [[3324, 54353], [3_452_435, 3_321_421]],
            "parent" => %{"child" => %{"foo" => 3}}
          },
          "list[0][1], parent.child.foo"
        ],
        [
          "a large number of nests within a lists",
          %{
            "list" => [
              [
                [
                  [
                    [1, 4],
                    [24, 543]
                  ],
                  [
                    [134, 4653],
                    [234_231, 2_353_454]
                  ]
                ],
                [
                  [
                    [1_023_983, 239_845],
                    [45332, 43545]
                  ],
                  [
                    [3, 9],
                    [3242, 44]
                  ]
                ]
              ],
              [
                [
                  [
                    [1234, 546],
                    [12312, 5_439_645]
                  ],
                  [
                    [2, 55],
                    [4665, 76754]
                  ]
                ],
                [
                  [
                    [93_543_245, 8_141_232],
                    [4564, 4567]
                  ],
                  [
                    [10_214_235, 143_534_251],
                    [124_112, 153_425_343]
                  ]
                ]
              ]
            ]
          },
          "list[0][0][0][0][1], list[0][1][1][0][0]"
        ]
      ])
    end

    test "should access nested source values when specified in conditionals" do
      transformation1 =
        TDG.create_transformation(%{
          name: "sample",
          type: "add",
          parameters: %{
            "condition" => "true",
            "conditionCompareTo" => "Target Field",
            "conditionDataType" => "string",
            "sourceConditionField" => "sourceTestField.inner",
            "conditionOperation" => "=",
            "targetConditionField" => "targetTestField.inner",
            "targetConditionValue" => nil,
            "addends" => "5, parent.child",
            "targetField" => "parent.child"
          },
          sequence: 0
        })

      operations =
        [transformation1]
        |> Transformers.construct()

      initial_payload = %{
        "sourceTestField" => %{"inner" => "knownValue"},
        "targetTestField" => %{"inner" => "knownValue"},
        "parent" => %{
          "child" => 9
        }
      }

      {:ok, resulting_payload} = Transformers.perform(operations, initial_payload)

      assert resulting_payload == %{
               "sourceTestField" => %{"inner" => "knownValue"},
               "targetTestField" => %{"inner" => "knownValue"},
               "parent" => %{
                 "child" => 14
               }
             }
    end
  end

  describe "put_value_with_accessor_keys" do
    test "simple map put" do
      value = "foo"
      accessor_keys = ["top"]

      actual = Transformers.put_value_with_accessor_keys(value, accessor_keys, %{})
      assert actual == %{"top" => "foo"}
    end

    test "merged map put" do
      value = "foo"
      accessor_keys = ["top"]
      existing_acc = %{"parent" => [4, 2_438_509], "bar" => 3}

      actual = Transformers.put_value_with_accessor_keys(value, accessor_keys, existing_acc)
      assert actual == %{"top" => "foo", "parent" => [4, 2_438_509], "bar" => 3}
    end

    test "simple list put" do
      value = "foo"
      accessor_keys = ["top", 0]

      actual = Transformers.put_value_with_accessor_keys(value, accessor_keys, %{})
      assert actual == %{"top" => ["foo"]}
    end

    test "list of map put" do
      value = "foo"
      accessor_keys = ["top", 0, "bottom"]

      actual = Transformers.put_value_with_accessor_keys(value, accessor_keys, %{})
      assert actual == %{"top" => [%{"bottom" => "foo"}]}
    end

    test "nested list put" do
      value = "foo"
      accessor_keys = ["top", 0, 0, 0]

      actual = Transformers.put_value_with_accessor_keys(value, accessor_keys, %{})
      assert actual == %{"top" => [[["foo"]]]}
    end

    test "putting into a combined list and map structure" do
      value = "foo"
      accessor_keys = ["grandParent", 0, 0, "parent", 0, "child"]

      actual = Transformers.put_value_with_accessor_keys(value, accessor_keys, %{})
      assert actual == %{"grandParent" => [[%{"parent" => [%{"child" => "foo"}]}]]}
    end

    test "putting into a combined list and map structure based on previous acc" do
      value = "foo"
      accessor_keys = ["grandParent", 0, 0, "parent", 1, "child"]
      previous_acc = %{"grandParent" => [[%{"parent" => [%{"child" => "bar"}]}]]}

      actual = Transformers.put_value_with_accessor_keys(value, accessor_keys, previous_acc)

      expected = %{
        "grandParent" => [[%{"parent" => [%{"child" => "bar"}, %{"child" => "foo"}]}]]
      }

      assert actual == expected
    end

    test "putting into a nested list of more than 10 elements" do
      value = -99.79152222299996

      previous_acc = %{
        "geometry" => %{
          "coordinates" => [
            [
              -93.79152224399996,
              41.61494825200003
            ],
            [
              -93.79150531999994,
              41.61501428300005
            ],
            [
              -93.79140579199998,
              41.61557707600008
            ],
            [
              -93.79134543099997,
              41.61578244400005
            ],
            [
              -93.79128030499999,
              41.615977213000065
            ],
            [
              -93.79120089199995,
              41.616140173000076
            ],
            [
              -93.79107900999998,
              41.61629616500005
            ],
            [
              -93.79055801099997,
              41.61681760700003
            ],
            [
              -93.79013560199996,
              41.617246805000036
            ],
            [
              -93.78983055299994,
              41.61756248000006
            ]
          ]
        }
      }

      accessor_keys = ["geometry", "coordinates", 10, 0]

      actual = Transformers.put_value_with_accessor_keys(value, accessor_keys, previous_acc)

      expected = %{
        "geometry" => %{
          "coordinates" => [
            [
              -93.79152224399996,
              41.61494825200003
            ],
            [
              -93.79150531999994,
              41.61501428300005
            ],
            [
              -93.79140579199998,
              41.61557707600008
            ],
            [
              -93.79134543099997,
              41.61578244400005
            ],
            [
              -93.79128030499999,
              41.615977213000065
            ],
            [
              -93.79120089199995,
              41.616140173000076
            ],
            [
              -93.79107900999998,
              41.61629616500005
            ],
            [
              -93.79055801099997,
              41.61681760700003
            ],
            [
              -93.79013560199996,
              41.617246805000036
            ],
            [
              -93.78983055299994,
              41.61756248000006
            ],
            [value]
          ]
        }
      }

      assert actual == expected
    end

    test "put into fields with hyphens" do
      value = "foo"
      accessor_keys = ["top", 0, "inner-field", 0]

      actual = Transformers.put_value_with_accessor_keys(value, accessor_keys, %{})
      assert actual == %{"top" => [%{"inner-field" => ["foo"]}]}
    end
  end

  describe "split_key_into_accessors" do
    test "simple map split" do
      key = "bar"
      expected = ["bar"]

      actual = Transformers.split_key_into_accessors(key)
      assert actual == expected
    end

    test "simple list split" do
      key = "top[0]"
      expected = ["top", 0]

      actual = Transformers.split_key_into_accessors(key)
      assert actual == expected
    end

    test "list of map split" do
      key = "top[3].bar"
      expected = ["top", 3, "bar"]

      actual = Transformers.split_key_into_accessors(key)
      assert actual == expected
    end

    test "nested list split" do
      key = "top[3][2][6].bar"
      expected = ["top", 3, 2, 6, "bar"]

      actual = Transformers.split_key_into_accessors(key)
      assert actual == expected
    end

    test "split from a combined list and map structure" do
      key = "top[3][2].bar[6].child"
      expected = ["top", 3, 2, "bar", 6, "child"]

      actual = Transformers.split_key_into_accessors(key)
      assert actual == expected
    end

    test "split a nested list deeper than 10 elements" do
      key = "top[1][11].bar"
      expected = ["top", 1, 11, "bar"]

      actual = Transformers.split_key_into_accessors(key)
      assert actual == expected
    end

    test "split on fields with hyphens" do
      key = "top[1][11]some-map[0]"
      expected = ["top", 1, 11, "some-map", 0]

      actual = Transformers.split_key_into_accessors(key)
      assert actual == expected
    end
  end
end
