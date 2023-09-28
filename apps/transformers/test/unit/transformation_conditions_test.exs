defmodule Transformers.ConditionsTest do
  use ExUnit.Case
  import Checkov

  alias Transformers.Conditions

  describe "Transformation Conditions" do
    test "returns true if no condition present" do
      parameters = %{
        "targetField" => "testField",
        "newValue" => "new value",
        "conditionDataType" => "string"
      }

      payload = %{
        "testField" => "value"
      }

      {type, result} = Conditions.check(payload, parameters)
      assert type == :ok
      assert result == true
    end

    test "returns true if condition is present and is false" do
      parameters = %{
        "targetField" => "testField",
        "newValue" => "new value",
        "conditionDataType" => "string",
        "condition" => "false"
      }

      payload = %{
        "testField" => "value"
      }

      {type, result} = Conditions.check(payload, parameters)
      assert type == :ok
      assert result == true
    end

    test "returns true if condition is present and is nil" do
      parameters = %{
        "targetField" => "testField",
        "newValue" => "new value",
        "conditionDataType" => "string",
        "condition" => nil
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
        "condition" => "true",
        "conditionCompareTo" => "Static Value",
        "conditionDataType" => "string",
        "sourceConditionField" => "testField",
        "conditionOperation" => "=",
        "targetConditionField" => nil,
        "targetConditionValue" => "value"
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
        "condition" => "true",
        "conditionCompareTo" => "Static Value",
        "conditionDataType" => "string",
        "sourceConditionField" => "testField",
        "conditionOperation" => "=",
        "targetConditionField" => nil,
        "targetConditionValue" => "differentValue"
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
        "condition" => "true",
        "conditionCompareTo" => "Target Field",
        "conditionDataType" => "string",
        "sourceConditionField" => "testField",
        "conditionOperation" => "=",
        "targetConditionField" => "compareField",
        "targetConditionValue" => nil
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
        "condition" => "true",
        "conditionCompareTo" => "Target Field",
        "conditionDataType" => "string",
        "sourceConditionField" => "testField",
        "conditionOperation" => "=",
        "targetConditionField" => "compareField",
        "targetConditionValue" => nil
      }

      payload = %{
        "testField" => "value",
        "compareField" => "othervalue"
      }

      result = Conditions.check(payload, parameters)
      assert result == {:ok, false}
    end

    data_test "returns #{expected_result} null condition" do
      parameters = %{
        "targetField" => "testField",
        "newValue" => "new value",
        "condition" => "true",
        "conditionCompareTo" => "Null or Empty",
        "conditionDataType" => condition_data_type,
        "sourceConditionField" => "testField",
        "conditionOperation" => operation,
        "targetConditionField" => nil,
        "targetConditionValue" => nil
      }

      payload = %{
        "testField" => test_field
      }

      result = Conditions.check(payload, parameters)
      assert result == {:ok, expected_result}

      where([
        [:condition_data_type, :operation, :expected_result, :test_field],
        ["String", "=", true, nil],
        ["String", "=", false, "asdf"],
        ["String", "!=", false, nil],
        ["String", "!=", true, "asdf"],
        ["Number", "=", true, nil],
        ["Number", "=", false, 2],
        ["Number", "!=", false, nil],
        ["Number", "!=", true, 2],
        ["DateTime", "=", true, nil],
        ["DateTime", "=", false, DateTime.utc_now()],
        ["DateTime", "!=", false, nil],
        ["DateTime", "!=", true, DateTime.utc_now()]
      ])
    end

    test "maps operation string 'Is Equal To'" do
      parameters = %{
        "targetField" => "testField",
        "newValue" => "new value",
        "condition" => "true",
        "conditionCompareTo" => "Target Field",
        "conditionDataType" => "string",
        "sourceConditionField" => "testField",
        "conditionOperation" => "Is Equal To",
        "targetConditionField" => "compareField",
        "targetConditionValue" => nil
      }

      payload = %{
        "testField" => "value",
        "compareField" => "value"
      }

      result = Conditions.check(payload, parameters)
      assert result == {:ok, true}
    end

    test "parses condition data type string with capital letter" do
      parameters = %{
        "targetField" => "testField",
        "newValue" => "new value",
        "condition" => "true",
        "conditionCompareTo" => "Target Field",
        "conditionDataType" => "String",
        "sourceConditionField" => "testField",
        "conditionOperation" => "Is Equal To",
        "targetConditionField" => "compareField",
        "targetConditionValue" => nil
      }

      payload = %{
        "testField" => "value",
        "compareField" => "value"
      }

      result = Conditions.check(payload, parameters)
      assert result == {:ok, true}
    end

    test "returns true when source field is a boolean and provided value are equal" do
      parameters = %{
        "targetField" => "testField",
        "newValue" => "new value",
        "condition" => "true",
        "conditionCompareTo" => "Static Value",
        "conditionDataType" => "string",
        "sourceConditionField" => "testField",
        "conditionOperation" => "=",
        "targetConditionField" => nil,
        "targetConditionValue" => "true"
      }

      payload = %{
        "testField" => true
      }

      result = Conditions.check(payload, parameters)
      assert result == {:ok, true}
    end

    test "returns true when source field and target field are boolean and they are equal" do
      parameters = %{
        "targetField" => "testField",
        "newValue" => "new value",
        "condition" => "true",
        "conditionCompareTo" => "Target Field",
        "conditionDataType" => "string",
        "sourceConditionField" => "testField",
        "conditionOperation" => "=",
        "targetConditionField" => "compareField",
        "targetConditionValue" => nil
      }

      payload = %{
        "testField" => true,
        "compareField" => true
      }

      result = Conditions.check(payload, parameters)
      assert result == {:ok, true}
    end

    test "returns true when source field is string boolean and target field is boolean and they are equal" do
      parameters = %{
        "targetField" => "testField",
        "newValue" => "new value",
        "condition" => "true",
        "conditionCompareTo" => "Target Field",
        "conditionDataType" => "string",
        "sourceConditionField" => "testField",
        "conditionOperation" => "=",
        "targetConditionField" => "compareField",
        "targetConditionValue" => nil
      }

      payload = %{
        "testField" => "true",
        "compareField" => true
      }

      result = Conditions.check(payload, parameters)
      assert result == {:ok, true}
    end
  end

  describe "not equals" do
    test "returns true when source field and provided value are not equal" do
      parameters = %{
        "targetField" => "testField",
        "newValue" => "new value",
        "condition" => "true",
        "conditionCompareTo" => "Static Value",
        "conditionDataType" => "string",
        "sourceConditionField" => "testField",
        "conditionOperation" => "!=",
        "targetConditionField" => nil,
        "targetConditionValue" => "othervalue"
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
        "condition" => "true",
        "conditionCompareTo" => "Static Value",
        "conditionDataType" => "string",
        "sourceConditionField" => "testField",
        "conditionOperation" => "!=",
        "targetConditionField" => nil,
        "targetConditionValue" => "value"
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
        "condition" => "true",
        "conditionCompareTo" => "Target Field",
        "conditionDataType" => "string",
        "sourceConditionField" => "testField",
        "conditionOperation" => "!=",
        "targetConditionField" => "compareField",
        "targetConditionValue" => nil
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
        "condition" => "true",
        "conditionCompareTo" => "Target Field",
        "conditionDataType" => "string",
        "sourceConditionField" => "testField",
        "conditionOperation" => "!=",
        "targetConditionField" => "compareField",
        "targetConditionValue" => nil
      }

      payload = %{
        "testField" => "value",
        "compareField" => "value"
      }

      result = Conditions.check(payload, parameters)
      assert result == {:ok, false}
    end

    test "maps operation string 'Is Not Equal To'" do
      parameters = %{
        "targetField" => "testField",
        "newValue" => "new value",
        "condition" => "true",
        "conditionCompareTo" => "Static Value",
        "conditionDataType" => "string",
        "sourceConditionField" => "testField",
        "conditionOperation" => "Is Not Equal To",
        "targetConditionField" => nil,
        "targetConditionValue" => "othervalue"
      }

      payload = %{
        "testField" => "value"
      }

      result = Conditions.check(payload, parameters)
      assert result == {:ok, true}
    end
  end

  describe "greater than" do
    test "returns true when source field value is greater than static target value " do
      parameters = %{
        "targetField" => "testField",
        "newValue" => "new value",
        "condition" => "true",
        "conditionCompareTo" => "Static Value",
        "conditionDataType" => "number",
        "sourceConditionField" => "testField",
        "conditionOperation" => ">",
        "targetConditionField" => nil,
        "targetConditionValue" => "1"
      }

      payload = %{
        "testField" => 2
      }

      result = Conditions.check(payload, parameters)
      assert result == {:ok, true}
    end
  end

  describe "greater than or equal to" do
    test "returns true when source field value is equal to static target value" do
      parameters = %{
        "targetField" => "testField",
        "newValue" => "new value",
        "valueType" => "string",
        "condition" => "true",
        "conditionCompareTo" => "Static Value",
        "conditionDataType" => "number",
        "sourceConditionField" => "testField",
        "conditionOperation" => ">=",
        "targetConditionField" => nil,
        "targetConditionValue" => "1"
      }

      payload = %{
        "testField" => 1
      }

      result = Conditions.check(payload, parameters)
      assert result == {:ok, true}
    end

    test "returns true when source field value is greater than or equal to static target value 2" do
      parameters = %{
        "targetField" => "testField",
        "newValue" => "new value",
        "valueType" => "string",
        "condition" => "true",
        "conditionCompareTo" => "Static Value",
        "conditionDataType" => "number",
        "sourceConditionField" => "testField",
        "conditionOperation" => ">=",
        "targetConditionField" => nil,
        "targetConditionValue" => "2"
      }

      payload = %{
        "testField" => 2
      }

      result = Conditions.check(payload, parameters)
      assert result == {:ok, true}
    end

    test "returns true when source field value is less than static target value" do
      parameters = %{
        "targetField" => "testField",
        "newValue" => "new value",
        "valueType" => "string",
        "condition" => "true",
        "conditionCompareTo" => "Static Value",
        "conditionDataType" => "number",
        "sourceConditionField" => "testField",
        "conditionOperation" => "<=",
        "targetConditionField" => nil,
        "targetConditionValue" => "2"
      }

      payload = %{
        "testField" => 1
      }

      result = Conditions.check(payload, parameters)
      assert result == {:ok, true}
    end

    test "returns true when source field value is less than or 'equal to' static target value 1" do
      parameters = %{
        "targetField" => "testField",
        "newValue" => "new value",
        "valueType" => "string",
        "condition" => "true",
        "conditionCompareTo" => "Static Value",
        "conditionDataType" => "number",
        "sourceConditionField" => "testField",
        "conditionOperation" => "<=",
        "targetConditionField" => nil,
        "targetConditionValue" => "1"
      }

      payload = %{
        "testField" => 1
      }

      result = Conditions.check(payload, parameters)
      assert result == {:ok, true}
    end
  end

  test "returns false when source field value is less than static target value " do
    parameters = %{
      "targetField" => "testField",
      "newValue" => "new value",
      "condition" => "true",
      "conditionCompareTo" => "Static Value",
      "conditionDataType" => "number",
      "sourceConditionField" => "testField",
      "conditionOperation" => ">",
      "targetConditionField" => nil,
      "targetConditionValue" => "3"
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
      "condition" => "true",
      "conditionCompareTo" => "Target Field",
      "conditionDataType" => "number",
      "sourceConditionField" => "testField",
      "conditionOperation" => ">",
      "targetConditionField" => "compareField",
      "targetConditionValue" => nil
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
      "condition" => "true",
      "conditionCompareTo" => "Target Field",
      "conditionDataType" => "number",
      "sourceConditionField" => "testField",
      "conditionOperation" => ">",
      "targetConditionField" => "compareField",
      "targetConditionValue" => nil
    }

    payload = %{
      "testField" => 2,
      "compareField" => 3
    }

    result = Conditions.check(payload, parameters)
    assert result == {:ok, false}
  end

  test "maps operation string 'Is Greater Than'" do
    parameters = %{
      "targetField" => "testField",
      "newValue" => "new value",
      "condition" => "true",
      "conditionCompareTo" => "Static Value",
      "conditionDataType" => "number",
      "sourceConditionField" => "testField",
      "conditionOperation" => "Is Greater Than",
      "targetConditionField" => nil,
      "targetConditionValue" => "1"
    }

    payload = %{
      "testField" => 2
    }

    result = Conditions.check(payload, parameters)
    assert result == {:ok, true}
  end

  describe "less than" do
    test "returns true when source field value is less than static target value " do
      parameters = %{
        "targetField" => "testField",
        "newValue" => "new value",
        "condition" => "true",
        "conditionCompareTo" => "Static Value",
        "conditionDataType" => "number",
        "sourceConditionField" => "testField",
        "conditionOperation" => "<",
        "targetConditionField" => nil,
        "targetConditionValue" => "3"
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
        "condition" => "true",
        "conditionCompareTo" => "Static Value",
        "conditionDataType" => "number",
        "sourceConditionField" => "testField",
        "conditionOperation" => "<",
        "targetConditionField" => nil,
        "targetConditionValue" => "1"
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
        "condition" => "true",
        "conditionCompareTo" => "Target Field",
        "conditionDataType" => "number",
        "sourceConditionField" => "testField",
        "conditionOperation" => "<",
        "targetConditionField" => "compareField",
        "targetConditionValue" => nil
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
        "condition" => "true",
        "conditionCompareTo" => "Target Field",
        "conditionDataType" => "number",
        "sourceConditionField" => "testField",
        "conditionOperation" => "<",
        "targetConditionField" => "compareField",
        "targetConditionValue" => nil
      }

      payload = %{
        "testField" => 2,
        "compareField" => 1
      }

      result = Conditions.check(payload, parameters)
      assert result == {:ok, false}
    end

    test "maps operation string 'Is Less Than'" do
      parameters = %{
        "targetField" => "testField",
        "newValue" => "new value",
        "condition" => "true",
        "conditionCompareTo" => "Static Value",
        "conditionDataType" => "number",
        "sourceConditionField" => "testField",
        "conditionOperation" => "Is Less Than",
        "targetConditionField" => nil,
        "targetConditionValue" => "3"
      }

      payload = %{
        "testField" => 2
      }

      result = Conditions.check(payload, parameters)
      assert result == {:ok, true}
    end
  end

  describe "datetime" do
    test "converts inputted datetimes to their respective formats and performs the comparison" do
      parameters = %{
        "targetField" => "testField",
        "newValue" => "new value",
        "condition" => "true",
        "conditionCompareTo" => "Target Field",
        "conditionDataType" => "datetime",
        "sourceConditionField" => "testField",
        "conditionSourceDateFormat" => "{YYYY}-{0M}-{D} {h24}:{m}",
        "conditionOperation" => "=",
        "targetConditionField" => "compareField",
        "conditionTargetDateFormat" => "{Mfull} {D}, {YYYY} {h12}:{m} {AM}"
      }

      payload = %{
        "testField" => "2022-02-28 16:53",
        "compareField" => "February 28, 2022 4:53 PM"
      }

      result = Conditions.check(payload, parameters)
      assert result == {:ok, true}
    end
  end

  describe "error handling" do
    test "returns error when the comparison fields are missing from the parameters" do
      parameters = %{
        "conditionCompareTo" => "Target Field",
        "condition" => "true",
        "conditionDataType" => "number",
        "sourceConditionField" => "testField",
        "conditionOperation" => "="
      }

      payload = %{
        "testField" => 2
      }

      result = Conditions.check(payload, parameters)
      assert result == {:error, %{"targetConditionField" => "Missing or empty field"}}
    end

    test "returns error when the source field is missing from the parameters" do
      parameters = %{
        "condition" => "true",
        "conditionDataType" => "number",
        "conditionOperation" => "=",
        "targetConditionValue" => "2",
        "conditionCompareTo" => "Static Value"
      }

      payload = %{
        "testField" => 2
      }

      result = Conditions.check(payload, parameters)
      assert result == {:error, %{"sourceConditionField" => "Missing or empty field"}}
    end

    test "returns error when the operation field is missing from the parameters" do
      parameters = %{
        "condition" => "true",
        "conditionDataType" => "number",
        "sourceConditionField" => "testField",
        "targetConditionValue" => "2",
        "conditionCompareTo" => "Static Value"
      }

      payload = %{
        "testField" => 2
      }

      result = Conditions.check(payload, parameters)
      assert result == {:error, %{"conditionOperation" => "Missing or empty field"}}
    end

    test "returns error when given an unsupported operation" do
      parameters = %{
        "condition" => "true",
        "conditionDataType" => "number",
        "sourceConditionField" => "testField",
        "conditionOperation" => "!",
        "targetConditionValue" => "2",
        "conditionCompareTo" => "Static Value"
      }

      payload = %{
        "testField" => 2
      }

      condition_operation = Conditions.check(payload, parameters)

      assert condition_operation ==
               {:error, "unsupported condition operation !"}
    end

    test "returns error when source field is not present in payload" do
      parameters = %{
        "condition" => "true",
        "conditionDataType" => "number",
        "sourceConditionField" => "testField",
        "conditionOperation" => "=",
        "targetConditionValue" => "2",
        "conditionCompareTo" => "Static Value"
      }

      payload = %{
        "notTestField" => 2
      }

      result = Conditions.check(payload, parameters)

      assert result ==
               {:error, %KeyError{key: "testField", message: nil, term: %{"notTestField" => 2}}}
    end

    test "returns error when data type field is not present in payload" do
      parameters = %{
        "condition" => "true",
        "sourceConditionField" => "testField",
        "conditionOperation" => "=",
        "targetConditionValue" => "2",
        "conditionCompareTo" => "Static Value"
      }

      payload = %{
        "testField" => 2
      }

      result = Conditions.check(payload, parameters)

      assert result == {:error, %{"conditionDataType" => "Missing or empty field"}}
    end

    test "returns error when data type is datetime and source format field is missing" do
      parameters = %{
        "targetField" => "testField",
        "newValue" => "new value",
        "condition" => "true",
        "conditionCompareTo" => "Target Field",
        "conditionDataType" => "datetime",
        "sourceConditionField" => "testField",
        "conditionOperation" => "=",
        "targetConditionField" => "compareField",
        "conditionTargetDateFormat" => "{Mfull} {D}, {YYYY} {h12}:{m} {AM}"
      }

      payload = %{
        "testField" => "2022-02-28 16:53",
        "compareField" => "February 28, 2022 4:53 PM"
      }

      result = Conditions.check(payload, parameters)
      assert result == {:error, %{"conditionSourceDateFormat" => "Missing or empty field"}}
    end
  end

  test "returns error when data type is datetime and target format field is missing" do
    parameters = %{
      "targetField" => "testField",
      "newValue" => "new value",
      "condition" => "true",
      "conditionCompareTo" => "Target Field",
      "conditionDataType" => "datetime",
      "sourceConditionField" => "testField",
      "conditionSourceDateFormat" => "{YYYY}-{0M}-{D} {h24}:{m}",
      "conditionOperation" => "=",
      "targetConditionField" => "compareField"
    }

    payload = %{
      "testField" => "2022-02-28 16:53",
      "compareField" => "February 28, 2022 4:53 PM"
    }

    result = Conditions.check(payload, parameters)
    assert result == {:error, %{"conditionTargetDateFormat" => "Missing or empty field"}}
  end

  test "returns error when invalid datetime format provided" do
    parameters = %{
      "targetField" => "testField",
      "newValue" => "new value",
      "condition" => "true",
      "conditionCompareTo" => "Target Field",
      "conditionDataType" => "datetime",
      "sourceConditionField" => "testField",
      "conditionSourceDateFormat" => "{YYYY}-{0M}-{D} {h24}:{m}",
      "conditionOperation" => "=",
      "targetConditionField" => "compareField",
      "conditionTargetDateFormat" => "totallyADateFormat"
    }

    payload = %{
      "testField" => "2022-02-28 16:53",
      "compareField" => "February 28, 2022 4:53 PM"
    }

    result = Conditions.check(payload, parameters)

    assert result ==
             {:error,
              %{
                "conditionTargetDateFormat" =>
                  "DateTime format \"totallyADateFormat\" is invalid: Invalid format string, must contain at least one directive."
              }}
  end
end
