defmodule Transformers.RemoveTest do
  use ExUnit.Case

  alias Transformers.Remove

  test "if source field not specified, return error" do
    payload = %{
      dead_field: "goodbye"
    }

    parameters = %{}

    {:error, reason} = Remove.transform(payload, parameters)

    assert reason == "Missing transformation parameter: sourceField"
  end

  test "if source field not on payload, return error" do
    payload = %{
      undead_field: "goodbye"
    }

    parameters = %{
      sourceField: "dead_field"
    }

    {:error, reason} = Remove.transform(payload, parameters)

    assert reason == "Missing field in payload: dead_field"
  end
end
