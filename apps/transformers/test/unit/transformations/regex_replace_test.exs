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

    assert reason == "Missing transformation parameter: #{parameter}"

    where(parameter: ["sourceField", "regex", "replacement"])
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

    assert reason == "Missing field in payload: something"
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

    assert reason == "Invalid regular expression: missing ) at index 3"
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

    assert reason == "Value of field replacement is not a string: 123"
  end

  test "if source field is not a string, return error" do
    payload = %{
      "something" => 123
    }

    parameters = %{
      "sourceField" => "something",
      "regex" => "123",
      "replacement" => "abc"
    }

    {:error, reason} = RegexReplace.transform(payload, parameters)

    assert reason == "Value of field something is not a string: 123"
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
end
