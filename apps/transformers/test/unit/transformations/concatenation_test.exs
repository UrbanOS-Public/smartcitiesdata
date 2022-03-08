defmodule Transformers.ConcatenationTest do
  use ExUnit.Case
  use Checkov

  alias Transformers.Concatenation

  data_test "when missing parameter #{parameter} return error" do
    payload = %{
      "string1" => "one",
      "string2" => "two"
    }

    parameters =
      %{
        "sourceFields" => ["name", "last_name"],
        "separator" => ".",
        "targetField" => "full_name"
      }
      |> Map.delete(parameter)

    {:error, reason} = Concatenation.transform(payload, parameters)

    assert reason == "Missing transformation parameter: #{parameter}"

    where(parameter: ["sourceFields", "separator", "targetField"])
  end

  test "error if a source field is missing" do
    payload = %{
      "first_name" => "Sam"
    }

    parameters = %{
      "sourceFields" => ["first_name", "middle_initial", "last_name"],
      "separator" => ".",
      "targetField" => "full_name"
    }

    {:error, reason} = Concatenation.transform(payload, parameters)

    assert reason == "Missing field in payload: [middle_initial, last_name]"
  end

  test "return error if source fields not a list" do
    payload = %{
      "name" => "one",
      "name2" => "two"
    }

    parameters =
      %{
        "sourceFields" => "name",
        "separator" => ".",
        "targetField" => "full_name"
      }

      {:error, reason} = Concatenation.transform(payload, parameters)

      assert reason == "Expected list but received single value: sourceFields"
  end

  test "concatenate string fields into new field" do
    payload = %{
      "first_name" => "Sam",
      "middle_initial" => "I",
      "last_name" => "Am"
    }

    parameters = %{
      "sourceFields" => ["first_name", "middle_initial", "last_name"],
      "separator" => ".",
      "targetField" => "full_name"
    }

    {:ok, result} = Concatenation.transform(payload, parameters)

    assert "Sam.I.Am" == Map.get(result, "full_name")
    assert "Sam" == Map.get(result, "first_name")
    assert "I" == Map.get(result, "middle_initial")
    assert "Am" == Map.get(result, "last_name")
  end

  test "concatenate string fields into existing field" do
    payload = %{
      "name" => "Sam",
      "middle_initial" => "I",
      "last_name" => "Am"
    }

    parameters = %{
      "sourceFields" => ["name", "middle_initial", "last_name"],
      "separator" => ".",
      "targetField" => "name"
    }

    {:ok, result} = Concatenation.transform(payload, parameters)

    assert "Sam.I.Am" == Map.get(result, "name")
    assert "I" == Map.get(result, "middle_initial")
    assert "Am" == Map.get(result, "last_name")
  end

  test "concatenating an empty string works as expected" do
    payload = %{
      "name" => "Sam",
      "other" => ""
    }

    parameters = %{
      "sourceFields" => ["name", "other"],
      "separator" => ".",
      "targetField" => "name"
    }

    {:ok, result} = Concatenation.transform(payload, parameters)

    assert "Sam." == Map.get(result, "name")
    assert "" == Map.get(result, "other")
  end

  test "concatenating with nil works like empty string" do
    payload = %{
      "name" => "Sam",
      "other" => nil
    }

    parameters = %{
      "sourceFields" => ["name", "other"],
      "separator" => ".",
      "targetField" => "name"
    }

    {:ok, result} = Concatenation.transform(payload, parameters)

    assert "Sam." == Map.get(result, "name")
    assert nil == Map.get(result, "other")
  end

  test "converts integers to strings before concatenating" do
    payload = %{
      "other" => 123,
      "name" => "Sam",
    }

    parameters = %{
      "sourceFields" => ["other", "name"],
      "separator" => ".",
      "targetField" => "name"
    }

    {:ok, result} = Concatenation.transform(payload, parameters)

    assert "123.Sam" == Map.get(result, "name")
  end

  test "returns error if a source field cannot be converted to string" do
    payload = %{
      "other" => {:ok, "Hello"},
      "name" => "Sam",
    }

    parameters = %{
      "sourceFields" => ["other", "name"],
      "separator" => ".",
      "targetField" => "name"
    }

    {:error, result} = Concatenation.transform(payload, parameters)

    assert result == "Could not convert all source fields into strings"
  end
end
