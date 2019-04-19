defmodule Valkyrie.ValidatorsTest do
  use ExUnit.Case

  alias Valkyrie.Validators
  alias SmartCity.TestDataGenerator, as: TDG

  describe "schema_satisfied?/2" do
    test "returns true when payload structure matches schema" do
      cool_schema = [%{name: "id", type: "integer"}, %{name: "name", type: "string"}, %{name: "age", type: "integer"}]
      [msg] = TDG.create_data([dataset_id: "cool_data", payload: %{id: 123, name: "Benji", age: 31}], 1)

      assert Validators.schema_satisfied?(msg, cool_schema) == true
    end

    test "returns true when nested payload structure matches schema" do
    end

    test "returns true when a payload containing an array of nested structure matches schema" do
    end

    test "returns false when a payload doesn't match the schema" do
    end
  end
end
