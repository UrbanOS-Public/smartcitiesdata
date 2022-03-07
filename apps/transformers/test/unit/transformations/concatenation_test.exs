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
end
