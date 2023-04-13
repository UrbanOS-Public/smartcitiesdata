defmodule TransformationActionTest do
  use ExUnit.Case

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
