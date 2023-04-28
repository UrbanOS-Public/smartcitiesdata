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
        ["2 level map child", %{"parent" => %{"child" => %{"foo" => 4}}, "bar" => 3}, "parent.child.foo, bar"],
        ["both are inside map with doubled value", %{"parent" => %{"child" => %{"foo" => 4}, "bar" => 3}, "bar" => 34542}, "parent.child.foo, parent.bar"],
        ["get first value of list", %{"parent" => [4, 2438509], "bar" => 3}, "parent[0], bar"],
        ["fully nested lists", %{"list" => [ [135893, 4], [23425, 2842]], "list2" => [ [3324, 54353], [3452435, 3] ]}, "list[0][1], list2[1][1]"],
        ["multiple objects in list", %{"list" => [ [135893, 4], [23425, 2842]], "list2" => [ [3324, 54353], [3452435, 3321421] ], "parent" => %{"child" => %{"foo" => 3}}}, "list[0][1], parent.child.foo"],
        ["a large number of nests within a lists",
          %{"list" =>
            [
              [
                [
                  [
                    [1, 4], [24, 543]
                  ],
                  [
                    [134, 4653], [234231, 2353454]
                  ]
                ],
                [
                  [
                    [1023983, 239845], [45332, 43545]
                  ],
                  [
                    [3, 9], [3242, 44]
                  ]
                ]
              ],
              [
                [
                  [
                    [1234, 546], [12312, 5439645]
                  ],
                  [
                    [2, 55], [4665, 76754]
                  ]
                ],
                [
                  [
                    [93543245, 8141232], [4564, 4567]
                  ],
                  [
                    [10214235, 143534251], [124112, 153425343]
                  ]
                ]
              ]
            ]
          }, "list[0][0][0][0][1], list[0][1][1][0][0]"]
      ])
    end

    test "should perform operations with lists" do
      transformation1 =
        TDG.create_transformation(%{
          name: "sample",
          type: "add",
          parameters: %{
            "condition" => "false",
            "addends" => "5, parent_list[0].child",
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
        },
        "parent_list" => [
          %{"child" => 9}
        ]
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
               "parent_list" => [
                 %{"child" => 9}
               ],
               "concat" => "something, else"
             }
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

    test "should access listed source values when specified in conditionals" do
      transformation1 =
        TDG.create_transformation(%{
          name: "sample",
          type: "add",
          parameters: %{
            "condition" => "true",
            "conditionCompareTo" => "Target Field",
            "conditionDataType" => "string",
            "sourceConditionField" => "sourceTestField[0].inner",
            "conditionOperation" => "=",
            "targetConditionField" => "targetTestField.inner",
            "targetConditionValue" => nil,
            "addends" => [5, "parent.child"],
            "targetField" => "parent.child"
          },
          sequence: 0
        })

      operations =
        [transformation1]
        |> Transformers.construct()

      initial_payload = %{
        "sourceTestField" => [%{"inner" => "knownValue"}],
        "targetTestField" => %{"inner" => "knownValue"},
        "parent" => %{
          "child" => 9
        }
      }

      {:ok, resulting_payload} = Transformers.perform(operations, initial_payload)

      assert resulting_payload == %{
               "sourceTestField" => [%{"inner" => "knownValue"}],
               "targetTestField" => %{"inner" => "knownValue"},
               "parent" => %{
                 "child" => 14
               }
             }
    end
  end
end
