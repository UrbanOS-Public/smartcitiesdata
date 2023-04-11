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
  end
end
