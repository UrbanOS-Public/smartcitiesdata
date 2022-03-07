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

end
