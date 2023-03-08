defmodule Transformers.ConditionsTest do
  use ExUnit.Case

  alias Transformers.Conditions

  describe "Transformation Conditions" do
    test "returns true if no condition present" do
      parameters = %{
        "targetField" => "testField",
        "newValue" => "new value",
        "valueType" => "string"
      }

      payload = %{
        "testField" => "value"
      }

      {type, result} = Conditions.check(payload, parameters)
      assert type == :ok
      assert result == true
    end
  end

  describe "equals" do
    test "returns true when source field and provided value are equal" do
      parameters = %{
        "targetField" => "testField",
        "newValue" => "new value",
        "valueType" => "string",
        "condition" => %{
          "sourceConditionField" => "testField",
          "conditionOperation" => "=",
          "targetConditionField" => nil,
          "targetConditionValue" => "value"
        }
      }

      payload = %{
        "testField" => "value"
      }

      result = Conditions.check(payload, parameters)
      assert result == {:ok, true}
    end

    test "returns false when source field and provided value are not equal" do
      parameters = %{
        "targetField" => "testField",
        "newValue" => "new value",
        "valueType" => "string",
        "condition" => %{
          "sourceConditionField" => "testField",
          "conditionOperation" => "=",
          "targetConditionField" => nil,
          "targetConditionValue" => "differentValue"
        }
      }

      payload = %{
        "testField" => "value"
      }

      result = Conditions.check(payload, parameters)
      assert result == {:ok, false}
    end

    test "returns true when source and target field values are equal" do
      parameters = %{
        "targetField" => "testField",
        "newValue" => "new value",
        "valueType" => "string",
        "condition" => %{
          "sourceConditionField" => "testField",
          "conditionOperation" => "=",
          "targetConditionField" => "compareField",
          "targetConditionValue" => nil
        }
      }

      payload = %{
        "testField" => "value",
        "compareField" => "value"
      }

      result = Conditions.check(payload, parameters)
      assert result == {:ok, true}
    end

    test "returns false when source and target field values are not equal" do
      parameters = %{
        "targetField" => "testField",
        "newValue" => "new value",
        "valueType" => "string",
        "condition" => %{
          "sourceConditionField" => "testField",
          "conditionOperation" => "=",
          "targetConditionField" => "compareField",
          "targetConditionValue" => nil
        }
      }

      payload = %{
        "testField" => "value",
        "compareField" => "othervalue"
      }

      result = Conditions.check(payload, parameters)
      assert result == {:ok, false}
    end
  end

  describe "not equals" do
    test "returns true when source field and provided value are not equal" do
      parameters = %{
        "targetField" => "testField",
        "newValue" => "new value",
        "valueType" => "string",
        "condition" => %{
          "sourceConditionField" => "testField",
          "conditionOperation" => "!=",
          "targetConditionField" => nil,
          "targetConditionValue" => "othervalue"
        }
      }

      payload = %{
        "testField" => "value"
      }

      result = Conditions.check(payload, parameters)
      assert result == {:ok, true}
    end

    test "returns false when source field and provided value are equal" do
      parameters = %{
        "targetField" => "testField",
        "newValue" => "new value",
        "valueType" => "string",
        "condition" => %{
          "sourceConditionField" => "testField",
          "conditionOperation" => "!=",
          "targetConditionField" => nil,
          "targetConditionValue" => "value"
        }
      }

      payload = %{
        "testField" => "value"
      }

      result = Conditions.check(payload, parameters)
      assert result == {:ok, false}
    end

    test "returns true when source and target field values are not equal" do
      parameters = %{
        "targetField" => "testField",
        "newValue" => "new value",
        "valueType" => "string",
        "condition" => %{
          "sourceConditionField" => "testField",
          "conditionOperation" => "!=",
          "targetConditionField" => "compareField",
          "targetConditionValue" => nil
        }
      }

      payload = %{
        "testField" => "value",
        "compareField" => "other"
      }

      result = Conditions.check(payload, parameters)
      assert result == {:ok, true}
    end

    test "returns false when source and target field values are equal" do
      parameters = %{
        "targetField" => "testField",
        "newValue" => "new value",
        "valueType" => "string",
        "condition" => %{
          "sourceConditionField" => "testField",
          "conditionOperation" => "!=",
          "targetConditionField" => "compareField",
          "targetConditionValue" => nil
        }
      }

      payload = %{
        "testField" => "value",
        "compareField" => "value"
      }

      result = Conditions.check(payload, parameters)
      assert result == {:ok, false}
    end
  end

  describe "greater than" do
    test "returns true when source field value is greater than static target value " do
      parameters = %{
        "targetField" => "testField",
        "newValue" => "new value",
        "valueType" => "string",
        "condition" => %{
          "sourceConditionField" => "testField",
          "conditionOperation" => ">",
          "targetConditionField" => nil,
          "targetConditionValue" => "1"
        }
      }

      payload = %{
        "testField" => 2
      }

      result = Conditions.check(payload, parameters)
      assert result == {:ok, true}
    end

    test "returns false when source field value is less than static target value " do
      parameters = %{
        "targetField" => "testField",
        "newValue" => "new value",
        "valueType" => "string",
        "condition" => %{
          "sourceConditionField" => "testField",
          "conditionOperation" => ">",
          "targetConditionField" => nil,
          "targetConditionValue" => "3"
        }
      }

      payload = %{
        "testField" => 2
      }

      result = Conditions.check(payload, parameters)
      assert result == {:ok, false}
    end

    test "returns true when source field value is greater than target field value" do
      parameters = %{
        "targetField" => "testField",
        "newValue" => "new value",
        "valueType" => "string",
        "condition" => %{
          "sourceConditionField" => "testField",
          "conditionOperation" => ">",
          "targetConditionField" => "compareField",
          "targetConditionValue" => nil
        }
      }

      payload = %{
        "testField" => 2,
        "compareField" => 1
      }

      result = Conditions.check(payload, parameters)
      assert result == {:ok, true}
    end

    test "returns false when source field value is less than target field value" do
      parameters = %{
        "targetField" => "testField",
        "newValue" => "new value",
        "valueType" => "string",
        "condition" => %{
          "sourceConditionField" => "testField",
          "conditionOperation" => ">",
          "targetConditionField" => "compareField",
          "targetConditionValue" => nil
        }
      }

      payload = %{
        "testField" => 2,
        "compareField" => 3
      }

      result = Conditions.check(payload, parameters)
      assert result == {:ok, false}
    end
  end

  describe "less than" do
    test "returns true when source field value is less than static target value " do
      parameters = %{
        "targetField" => "testField",
        "newValue" => "new value",
        "valueType" => "string",
        "condition" => %{
          "sourceConditionField" => "testField",
          "conditionOperation" => "<",
          "targetConditionField" => nil,
          "targetConditionValue" => "3"
        }
      }

      payload = %{
        "testField" => 2
      }

      result = Conditions.check(payload, parameters)
      assert result == {:ok, true}
    end

    test "returns false when source field value is greater than static target value " do
      parameters = %{
        "targetField" => "testField",
        "newValue" => "new value",
        "valueType" => "string",
        "condition" => %{
          "sourceConditionField" => "testField",
          "conditionOperation" => "<",
          "targetConditionField" => nil,
          "targetConditionValue" => "1"
        }
      }

      payload = %{
        "testField" => 2
      }

      result = Conditions.check(payload, parameters)
      assert result == {:ok, false}
    end

    test "returns true when source field value is less than target field value" do
      parameters = %{
        "targetField" => "testField",
        "newValue" => "new value",
        "valueType" => "string",
        "condition" => %{
          "sourceConditionField" => "testField",
          "conditionOperation" => "<",
          "targetConditionField" => "compareField",
          "targetConditionValue" => nil
        }
      }

      payload = %{
        "testField" => 2,
        "compareField" => 3
      }

      result = Conditions.check(payload, parameters)
      assert result == {:ok, true}
    end

    test "returns false when source field value is greater than target field value" do
      parameters = %{
        "targetField" => "testField",
        "newValue" => "new value",
        "valueType" => "string",
        "condition" => %{
          "sourceConditionField" => "testField",
          "conditionOperation" => "<",
          "targetConditionField" => "compareField",
          "targetConditionValue" => nil
        }
      }

      payload = %{
        "testField" => 2,
        "compareField" => 1
      }

      result = Conditions.check(payload, parameters)
      assert result == {:ok, false}
    end
  end

  describe "error handling" do
    test "returns error when the comparison fields are missing from the parameters" do
      parameters = %{
        "condition" => %{
          "sourceConditionField" => "testField",
          "conditionOperation" => "="
        }
      }

      payload = %{
        "testField" => 2
      }

      result = Conditions.check(payload, parameters)
      assert result == {:error, %{"targetConditionField" => "Missing or empty field"}}
    end

    test "returns error when the source field is missing from the parameters" do
      parameters = %{
        "condition" => %{
          "conditionOperation" => "=",
          "targetConditionValue" => "2"
        }
      }

      payload = %{
        "testField" => 2
      }

      result = Conditions.check(payload, parameters)
      assert result == {:error, %{"sourceConditionField" => "Missing or empty field"}}
    end

    test "returns error when the operation field is missing from the parameters" do
      parameters = %{
        "condition" => %{
          "sourceConditionField" => "testField",
          "targetConditionValue" => "2"
        }
      }

      payload = %{
        "testField" => 2
      }

      result = Conditions.check(payload, parameters)
      assert result == {:error, %{"conditionOperation" => "Missing or empty field"}}
    end

    test "returns error when given an unsupported operation" do
      parameters = %{
        "condition" => %{
          "sourceConditionField" => "testField",
          "conditionOperation" => "!",
          "targetConditionValue" => "2"
        }
      }

      payload = %{
        "testField" => 2
      }

      result = Conditions.check(payload, parameters)
      assert result == {:error, "unsupported condition operation"}
    end

    test "returns error when source field is not present in payload" do
      parameters = %{
        "condition" => %{
          "sourceConditionField" => "testField",
          "conditionOperation" => "=",
          "targetConditionValue" => "2"
        }
      }

      payload = %{
        "notTestField" => 2
      }

      result = Conditions.check(payload, parameters)

      assert result ==
               {:error, %KeyError{key: "testField", message: nil, term: %{"notTestField" => 2}}}
    end
  end
end
