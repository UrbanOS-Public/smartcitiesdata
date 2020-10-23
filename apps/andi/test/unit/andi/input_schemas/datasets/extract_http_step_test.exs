defmodule Andi.InputSchemas.Datasets.ExtractHttpStepTest do
  use ExUnit.Case
  import Checkov

  alias Andi.InputSchemas.Datasets.ExtractHttpStep
  describe "body validation" do
    setup do
      changes = %{
        type: "http",
        method: "POST",
        url: "123.com",
        body: "",
        queryParams: %{"x" => "y"},
        headers: %{"api-key" => "to-my-heart"}
      }

      [changes: changes]
    end


    data_test "valid when body is #{inspect(value)}", %{changes: changes} do
      changes = Map.put(changes, :body, value)
      changeset = ExtractHttpStep.changeset(changes)

      assert changeset.errors[:body] == nil

      where([
        [:value],
        [""],
        [nil],
        ["[]"],
        ["[{}]"],
        ["[{\"bob\": 1}]"]
      ])
    end

    data_test "invalid when body is #{inspect(value)}", %{changes: changes} do
      changes = Map.put(changes, :body, value)
      changeset = ExtractHttpStep.changeset(changes)

      assert changeset.errors[:body] == {"could not parse json", [validation: :format]}

      where([
        [:value],
        ["this is invalid json"],
        ["{\"so is\": this"]
      ])
    end
  end
end
