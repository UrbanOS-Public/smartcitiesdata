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

end