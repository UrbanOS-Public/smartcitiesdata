defmodule Transformers.RegexReplaceTest do
  use ExUnit.Case
  use Checkov

  alias Transformers.RegexReplace

  data_test "returns error when #{parameter} not there" do
    payload = %{
      "something" => "abc"
    }

    parameters =
      %{
        "sourceField" => "something",
        "regex" => "a",
        "replacement" => "123"
      }
      |> Map.delete(parameter)

    {:error, reason} = RegexReplace.transform(payload, parameters)

    assert reason ==
             "Regex Replace Transformation Error: %{\"#{parameter}\" => \"Missing or empty field\"}"

    where(parameter: ["sourceField", "regex", "replacement"])
  end

  test "skips transformation when source field is nil" do
    params = %{
      "sourceField" => "status",
      "targetField" => "vendor",
      "replacement" => "replace",
      "regex" => "^\\((\\d{3})\\)"
    }

    message_payload = %{"status" => nil, "vendor" => "vendorname"}

    {:ok, transformed_payload} = Transformers.RegexReplace.transform(message_payload, params)

    assert message_payload == transformed_payload
  end

  data_test "returns error when #{parameter} ends in ." do
    payload = %{
      "something" => "abc"
    }

    parameters = %{
      "sourceField" => "something",
      "regex" => "a",
      "replacement" => "123"
    }

    invalid_parameter = Map.get(parameters, parameter)
    parameters = Map.put(parameters, parameter, "#{invalid_parameter}.")

    {:error, reason} = RegexReplace.transform(payload, parameters)

    assert reason ==
             "Regex Replace Transformation Error: %{\"#{parameter}\" => \"Missing or empty child field\"}"

    where(parameter: ["sourceField", "replacement"])
  end

  test "when source field not on message, return error" do
    payload = %{
      "something_unexpected" => "123"
    }

    parameters = %{
      "sourceField" => "something",
      "regex" => "^(\\w+)",
      "replacement" => "abc"
    }

    {:error, reason} = RegexReplace.transform(payload, parameters)

    assert reason == "Regex Replace Transformation Error: \"Missing field in payload: something\""
  end

  test "when regex does not compile, return error" do
    payload = %{
      "something" => "abc"
    }

    parameters = %{
      "sourceField" => "something",
      "regex" => "(()",
      "replacement" => "123"
    }

    {:error, reason} = RegexReplace.transform(payload, parameters)

    assert reason ==
             "Regex Replace Transformation Error: %{\"regex\" => \"Invalid regular expression: missing ) at index 3\"}"
  end

  test "when replacement is not a string, return error" do
    payload = %{
      "something" => "abc"
    }

    parameters = %{
      "sourceField" => "something",
      "regex" => "^(\\w+)",
      "replacement" => 123
    }

    {:error, reason} = RegexReplace.transform(payload, parameters)

    assert reason ==
             "Regex Replace Transformation Error: %{\"replacement\" => \"Not a string or list\"}"
  end

  test "if source field is not a string, convert to string" do
    payload = %{
      "something" => 123
    }

    parameters = %{
      "sourceField" => "something",
      "regex" => "(12)",
      "replacement" => "abc"
    }

    {:ok, result} = RegexReplace.transform(payload, parameters)

    assert result == %{"something" => "abc3"}
  end

  test "if no regex match, payload is unchanged" do
    payload = %{
      "something" => "abc"
    }

    parameters = %{
      "sourceField" => "something",
      "regex" => "def",
      "replacement" => "123"
    }

    {:ok, result} = RegexReplace.transform(payload, parameters)

    assert result == payload
  end

  test "if regex matches once, single match is replaced" do
    payload = %{
      "something" => "abc"
    }

    parameters = %{
      "sourceField" => "something",
      "regex" => "a",
      "replacement" => "123"
    }

    {:ok, result} = RegexReplace.transform(payload, parameters)

    assert result == %{"something" => "123bc"}
  end

  test "if regex matches multiple times, all matches are replaced" do
    payload = %{
      "something" => "abcabcdefabc"
    }

    parameters = %{
      "sourceField" => "something",
      "regex" => "abc",
      "replacement" => "123"
    }

    {:ok, result} = RegexReplace.transform(payload, parameters)

    assert result == %{"something" => "123123def123"}
  end

  test "performs transform as normal when condition evaluates to true" do
    payload = %{
      "something" => "abcabcdefabc"
    }

    parameters = %{
      "sourceField" => "something",
      "regex" => "abc",
      "replacement" => "123",
      "condition" => "true",
      "conditionCompareTo" => "Static Value",
      "conditionDataType" => "string",
      "sourceConditionField" => "something",
      "conditionOperation" => "=",
      "targetConditionValue" => "abcabcdefabc"
    }

    {:ok, result} = RegexReplace.transform(payload, parameters)

    assert result == %{"something" => "123123def123"}
  end

  test "does nothing when condition evaluates to false" do
    payload = %{
      "something" => "abcabcdefabc"
    }

    parameters = %{
      "sourceField" => "something",
      "regex" => "abc",
      "replacement" => "123",
      "condition" => "true",
      "conditionCompareTo" => "Static Value",
      "conditionDataType" => "string",
      "sourceConditionField" => "something",
      "conditionOperation" => "=",
      "targetConditionValue" => "other"
    }

    {:ok, result} = RegexReplace.transform(payload, parameters)

    assert result == %{"something" => "abcabcdefabc"}
  end

  describe "validate/1" do
    test "returns :ok if all parameters are present and valid" do
      parameters = %{
        "sourceField" => "something",
        "regex" => "a",
        "replacement" => "123"
      }

      {:ok, [source_field, replacement, regex]} = RegexReplace.validate(parameters)

      assert source_field == parameters["sourceField"]
      assert replacement == parameters["replacement"]
      assert regex == Regex.compile!(parameters["regex"])
    end

    data_test "when missing parameter #{parameter} return error" do
      parameters =
        %{
          "sourceField" => "something",
          "regex" => "a",
          "replacement" => "123"
        }
        |> Map.delete(parameter)

      {:error, reason} = RegexReplace.validate(parameters)

      assert reason == %{"#{parameter}" => "Missing or empty field"}

      where(parameter: ["sourceField", "replacement", "regex"])
    end

    test "returns error when regex is invalid" do
      parameters = %{
        "sourceField" => "something",
        "regex" => "(()",
        "replacement" => "123"
      }

      {:error, reason} = RegexReplace.validate(parameters)

      assert reason == %{"regex" => "Invalid regular expression: missing ) at index 3"}
    end
  end
end
