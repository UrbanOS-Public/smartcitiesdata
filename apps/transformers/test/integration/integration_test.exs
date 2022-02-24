defmodule Transformers.IntegrationTest do
  use ExUnit.Case
  alias SmartCity.Ingestion.Transformation

  test "do the things!" do
    parameters = %{
      sourceField: "full_name",
      targetField: "first_name",
      regex: "^(\\w+)"
    }
    transformation1 = Transformation.new(%{type: "regex_extract", parameters: parameters})

    parameters = %{
      sourceField: "full_name",
      targetField: "last_name",
      regex: "(\\w+)$"
    }
    transformation2 = Transformation.new(%{type: "regex_extract", parameters: parameters})
    transformations = [transformation1, transformation2]

    operations = Transformers.Construct.constructTransformation(transformations)
    payload = %{
      "full_name" => "Emily Shire"
    }

    {:ok, result} = Transformers.Perform.performTransformations(operations, payload)

    assert Map.get(result, "full_name") == "Emily Shire"
    assert Map.get(result, "first_name") == "Emily"
    assert Map.get(result, "last_name") == "Shire"
  end
end
