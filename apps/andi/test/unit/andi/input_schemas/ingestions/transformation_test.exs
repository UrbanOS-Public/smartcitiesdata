defmodule Andi.InputSchemas.Ingestions.TransformationTest do
  use ExUnit.Case

  alias Andi.InputSchemas.Ingestions.Transformation

  test "sucessfully validates a valid transformation" do
    changes = %{
      type: "concatenation",
      name: "name",
      parameters: %{
        "sourceFields" => ["other", "name"],
        "separator" => ".",
        "targetField" => "name"
      }
    }

    changeset =
      Transformation.changeset(Transformation.get_module(), changes)
      |> Transformation.validate()

    assert changeset.errors == []
    assert changeset.valid?
  end

  test "fails for an invalid transformation with atom key" do
    changes = %{
      type: "concatenation",
      name: "name",
      parameters: %{
        "sourceFields" => ["other", "name"],
        "targetField" => "name"
      }
    }

    changeset =
      Transformation.changeset(Transformation.get_module(), changes)
      |> Transformation.validate()

    assert changeset.errors == [{:separator, {"Missing field", []}}]
    assert not changeset.valid?
  end

  test "fails for empty parameters" do
    changes = %{
      type: "concatenation",
      parameters: nil
    }

    changeset =
      Transformation.changeset(Transformation.get_module(), changes)
      |> Transformation.validate()

    assert not changeset.valid?
    assert changeset.errors[:targetField] != nil
    assert {"Missing or empty field", []} == changeset.errors[:targetField]
    assert changeset.errors[:sourceFields] != nil
    assert {"Missing or empty field", []} == changeset.errors[:sourceFields]
    assert changeset.errors[:separator] != nil
    assert {"Missing field", []} == changeset.errors[:separator]
  end

  test "fails for invalid type" do
    changes = %{
      type: "invalid",
      parameters: %{}
    }

    changeset =
      Transformation.changeset(Transformation.get_module(), changes)
      |> Transformation.validate()

    assert not changeset.valid?
    assert changeset.errors[:type] != nil
    assert changeset.errors[:type] == {"Unsupported transformation validation type: invalid", []}
  end

  test "sucessfully creates an invalid changeset from form data when there is no transformation type selected" do
    id = UUID.uuid4()

    form_data = %{
      name: "Transformation Name",
      id: id,
      type: ""
    }

    changeset =
      Transformation.changeset(Transformation.get_module(), form_data)
      |> Transformation.validate()

    assert %Ecto.Changeset{changes: %{id: ^id, name: "Transformation Name", parameters: %{}}} = changeset
    refute changeset.valid?

    assert changeset.errors == [
             {:type, {"Unsupported transformation validation type: ", []}},
             {:type, {"is required", [validation: :required]}}
           ]
  end

  test "sucessfully creates a valid changeset from form data when there is a transformation type selected" do
    id = UUID.uuid4()

    form_data = %{
      name: "Transformation Name",
      id: id,
      type: "concatenation",
      sourceFields: ["other", "name"],
      separator: ".",
      targetField: "name"
    }

    changeset =
      Transformation.changeset(Transformation.get_module(), form_data)
      |> Transformation.validate()

    assert %Ecto.Changeset{
             changes: %{
               id: ^id,
               name: "Transformation Name",
               type: "concatenation",
               parameters: %{sourceFields: ["other", "name"], separator: ".", targetField: "name"}
             }
           } = changeset

    assert changeset.valid?
    assert changeset.errors == []
  end
end
