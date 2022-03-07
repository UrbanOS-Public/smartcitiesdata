defmodule Transformers.RegexReplaceTest do
  use ExUnit.Case

  alias Transformers.RegexReplace

  test "when source field not specified, return error" do
    payload = %{
      "something" => "123"
    }
    parameters = %{
      "regex" => "^(\\w+)",
      "replacement" => "a"
    }

    {:error, reason} = RegexReplace.transform(payload, parameters)

    assert reason == "Missing transformation parameter: source_field"
  end

  test "when regex not specified, return error" do
    payload = %{
      "something" => "123"
    }
    parameters = %{
      "source_field" => "something",
      "replacement" => "a"
    }

    {:error, reason} = RegexReplace.transform(payload, parameters)

    assert reason == "Missing transformation parameter: regex"
  end

  test "when replacement not specified, return error" do
    payload = %{
      "something" => "123"
    }
    parameters = %{
      "source_field" => "something",
      "regex" => "^(\\w+)"
    }

    {:error, reason} = RegexReplace.transform(payload, parameters)

    assert reason == "Missing transformation parameter: replacement"
  end

  test "when source field not on message, return error" do
    payload = %{
      "something_unexpected" => "123"
    }
    parameters = %{
      "source_field" => "something",
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
      "source_field" => "something",
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
      "source_field" => "something",
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
      "source_field" => "something",
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
      "source_field" => "something",
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
      "source_field" => "something",
      "regex" => "a",
      "replacement" => "123"
    }

    {:ok, result} = RegexReplace.transform(payload, parameters)

    assert result == %{"something" => "123bc"}
  end

end
