defmodule Transformers.ConstructAndPerformTest do
  use ExUnit.Case
  alias SmartCity.Ingestion.Transformation

  test "two transforms of same kind" do
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

    operations = Transformers.construct(transformations)

    payload = %{
      "full_name" => "Emily Shire"
    }

    {:ok, result} = Transformers.perform(operations, payload)

    assert Map.get(result, "full_name") == "Emily Shire"
    assert Map.get(result, "first_name") == "Emily"
    assert Map.get(result, "last_name") == "Shire"
  end

  test "two transforms of different kinds" do
    regex_params = %{
      regex: "^([0-9])",
      sourceField: "thing",
      targetField: "number"
    }

    transformation1 = Transformation.new(%{type: "regex_extract", parameters: regex_params})

    conversion_params = %{
      field: "number",
      sourceType: "string",
      targetType: "integer"
    }

    transformation2 = Transformation.new(%{type: "conversion", parameters: conversion_params})

    transformations = [transformation1, transformation2]
    operations = Transformers.construct(transformations)

    payload = %{
      "thing" => "123abc"
    }

    {:ok, result} = Transformers.perform(operations, payload)

    assert %{"thing" => "123abc", "number" => 1} == result
  end
end
