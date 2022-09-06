defmodule Transformers.ArithmeticAddTest do
  use ExUnit.Case

  alias Transformers.ArithmeticAdd

  describe "transform/2" do
    test "if addends are not specified, return error" do
      payload = %{
        "target" => 0
      }

      parameters = %{
        "targetField" => "target"
      }

      {:error, reason} = ArithmeticAdd.transform(payload, parameters)

      assert reason == %{"addends" => "Missing or empty field"}
    end

    test "if addends is an empty array, return error" do
      payload = %{
        "target" => 0
      }

      parameters = %{
        "targetField" => "target",
        "addends" => []
      }

      {:error, reason} = ArithmeticAdd.transform(payload, parameters)

      assert reason == %{"addends" => "Missing or empty field"}
    end

    test "if targetField is not specified, return error" do
      payload = %{
        "target" => 0
      }

      parameters = %{
        "addends" => [1]
      }

      {:error, reason} = ArithmeticAdd.transform(payload, parameters)

      assert reason == %{"targetField" => "Missing or empty field"}
    end

    test "when given two numbers, sets the target field to be equal to their sum" do
      payload = %{}

      parameters = %{
        "addends" => [1, 2],
        "targetField" => "targetField"
      }

      {:ok, result} = ArithmeticAdd.transform(payload, parameters)

      assert result == %{"targetField" => 3}
    end

    test "when given a field and a number, sets a new target field to be equal to their sum" do
      payload = %{
        "old_value" => 5
      }

      parameters = %{
        "addends" => ["old_value", 2],
        "targetField" => "new_value"
      }

      {:ok, result} = ArithmeticAdd.transform(payload, parameters)

      assert result == %{
               "old_value" => 5,
               "new_value" => 7
             }
    end

    # test "if a field key is a number, ...?!?" do

    test "if specified addend is not on payload, return error" do
      payload = %{
        "some_field" => 0
      }

      parameters = %{
        "addends" => ["target"],
        "targetField" => "some_field"
      }

      {:error, reason} = ArithmeticAdd.transform(payload, parameters)

      assert reason == "Missing field in payload: target"
    end

    # test "sets target field to addend when given single addend" do
    #   payload = %{
    #     "addends" => [1],
    #     "targetField" => "target"
    #   }

    #   payload = %{
    #     "target" => 0,
    #   }

    #   {:ok, result} = ArithmeticAdd.transform(payload, parameters)

    #   assert result == %{"target" => 1}
    # end

    # test "if addend field is not a number, return error" do
    #    payload = %{
    #      "addends" => ["target"],
    #      "targetField" => "target"
    #    }

    #   payload = %{
    #     "target" => "some string",
    #   }

    #   {:error, reason} = ArithmeticAdd.transform(payload, parameters)

    #   assert result == %{"target" => 1}
    # assert reason == %{"addends" => "Field is not a number"}
    #  # Note - should this reason be tied to the field associated with the non-number?
    # end
  end
end
