defmodule Transformers.TransformationFieldsTest do
  use ExUnit.Case

  alias Transformers.TransformationFields

  test "return fields for remove transform" do
    assert TransformationFields.fields_for("remove") == Transformers.Remove.fields()
  end

  test "return fields for add transform" do
    assert TransformationFields.fields_for("add") ==
             Transformers.Add.fields()
  end

  test "return fields for subtract transform" do
    assert TransformationFields.fields_for("subtract") ==
             Transformers.Subtract.fields()
  end

  test "return fields for multiplication transform" do
    assert TransformationFields.fields_for("multiplication") ==
             Transformers.Multiplication.fields()
  end

  test "return fields for division transform" do
    assert TransformationFields.fields_for("division") ==
             Transformers.Division.fields()
  end

  test "returns empty array for unsupported transformations" do
    assert TransformationFields.fields_for("") == []
    assert TransformationFields.fields_for("nonsense") == []
  end
end
