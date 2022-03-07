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
end
