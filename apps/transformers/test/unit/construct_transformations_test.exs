defmodule Transformers.ConstructTest do
  use ExUnit.Case
  alias SmartCity.Ingestion.Transformation
  alias Transformers.Utils

  test "when given 1 transformation, builds a list of 1 operation" do
    regex_params = %{
      sourceField: "phone_number",
      targetField: "area_code",
      regex: "^\\((\\d{3})\\)"
    }

    regex_transformation = Transformation.new(%{type: "regex_extract", parameters: regex_params})

    sc_transformations = [regex_transformation]

    result = Transformers.Construct.constructTransformation(sc_transformations)

    assert 1 == length(result)
    assert true == Utils.allOperationsItemsAreFunctions(result)
  end

  test "when given 3 transformations, builds a list of 3 operations" do
    regex_params = %{
      sourceField: "phone_number",
      targetField: "area_code",
      regex: "^\\((\\d{3})\\)"
    }

    regex_transformation1 = Transformation.new(%{type: "regex_extract", parameters: regex_params})
    regex_transformation2 = Transformation.new(%{type: "regex_extract", parameters: regex_params})
    regex_transformation3 = Transformation.new(%{type: "regex_extract", parameters: regex_params})

    sc_transformations = [regex_transformation1, regex_transformation2, regex_transformation3]

    result = Transformers.Construct.constructTransformation(sc_transformations)

    assert 3 == length(result)
    assert true == Utils.allOperationsItemsAreFunctions(result)
  end

  test "when given an empty array, returns an empty array" do
    result = Transformers.Construct.constructTransformation([])

    assert result == []
  end

  test "when type is missing result is an error" do
    result = Transformers.Construct.constructTransformation([%{parameters: {}}])
    assert result == [{:error, "Map provided is not a valid transformation"}]
  end

  test "when parameters are missing result is an error" do
    result = Transformers.Construct.constructTransformation([%{type: "regex_extract"}])
    assert result == [{:error, "Map provided is not a valid transformation"}]
  end
end
