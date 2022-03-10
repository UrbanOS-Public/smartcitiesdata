defmodule Andi.InputSchemas.Ingestions.TransformationTest do
  use ExUnit.Case

  alias Andi.InputSchemas.Ingestions.Transformation

  test "sucessfully validates a valid transformation" do
    changes = %{
      type: "concatenation",
      parameters: %{
        "sourceFields" => ["other", "name"],
        "separator" => ".",
        "targetField" => "name"
      }
    }

    changeset = Transformation.changeset(changes)

    assert changeset.errors == []
    assert changeset.valid?
  end

  test "fails for an invalid transformation" do
    changes = %{
      type: "concatenation",
      parameters: %{
        "sourceFields" => ["other", "name"],
        "targetField" => "name"
      }
    }

    changeset = Transformation.changeset(changes)

    assert changeset.errors == [{:parameters, {"Transformation not valid.", []}}]
    assert not changeset.valid?
  end

  test "fails for empty parameters" do
    changes = %{
      type: "concatenation",
      parameters: nil
    }

    changeset = Transformation.changeset(changes)
    assert not changeset.valid?
    assert changeset.errors[:parameters] != nil
    assert {"is required", [validation: :required]} == changeset.errors[:parameters]
  end

  test "fails for invalid type" do
    changes = %{
      type: "invalid",
      parameters: %{}
    }

    changeset = Transformation.changeset(changes)

    assert not changeset.valid?
    assert changeset.errors[:type] != nil
    assert changeset.errors[:type] == {"invalid type: invalid", []}
  end
end
