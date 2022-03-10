defmodule Transformers.ValidateTest do
  use ExUnit.Case

  test "given a list of one valid transformation, a single valid transformation response is returned" do
    transformation = %{
      type: "regex_extract",
      parameters: %{
        "sourceField" => "name",
        "targetField" => "firstName",
        "regex" => "^(\\w+)"
      }
    }

    assert [{:ok, "Transformation valid."}] ==
             Transformers.validate([transformation])
  end

  test "returns an error when the transformation is formatted incorrectly" do
    invalid_transformation = %{
      parameters: %{
        "sourceField" => "name",
        "targetField" => "firstName",
        "regex" => "^(\\w+)"
      }
    }

    assert [{:error, "Map provided is not a valid transformation"}] ==
             Transformers.validate([invalid_transformation])
  end

  test "multiple transformations return a list of valid transformation responses" do
    transformation1 = %{
      type: "regex_extract",
      parameters: %{
        "sourceField" => "name",
        "targetField" => "firstName",
        "regex" => "^(\\w+)"
      }
    }

    transformation2 = %{
      type: "regex_extract",
      parameters: %{
        "sourceField" => "name",
        "targetField" => "firstName",
        "regex" => "^(\\w+)"
      }
    }

    assert Transformers.validate([transformation1, transformation2]) ==
             [{:ok, "Transformation valid."}, {:ok, "Transformation valid."}]
  end

  test "returns results for both valid and invalid transformations" do
    transformation1 = %{
      type: "regex_extract",
      parameters: %{
        "sourceField" => "name",
        "targetField" => "firstName",
        "regex" => "^(\\w+)"
      }
    }

    transformation2 = %{
      type: "remove",
      parameters: %{}
    }

    assert Transformers.validate([transformation1, transformation2]) ==
             [{:ok, "Transformation valid."}, {:error, "Transformation not valid."}]
  end

  test "when provided an empty transformations list, an empty list is returned" do
    assert Transformers.validate([]) == []
  end
end
