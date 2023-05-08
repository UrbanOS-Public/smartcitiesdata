defmodule Transformers.ConstructAndPerformTest do
  use ExUnit.Case
  alias SmartCity.Ingestion.Transformation

  test "two transforms of same kind" do
    parameters = %{
      "sourceField" => "full_name",
      "targetField" => "first_name",
      "regex" => "^(\\w+)"
    }

    transformation1 =
      Transformation.new(%{type: "regex_extract", name: "Transformation", parameters: parameters})

    parameters = %{
      "sourceField" => "full_name",
      "targetField" => "last_name",
      "regex" => "(\\w+)$"
    }

    transformation2 =
      Transformation.new(%{type: "regex_extract", name: "Transformation", parameters: parameters})

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
      "regex" => "^([0-9])",
      "sourceField" => "thing",
      "targetField" => "number"
    }

    transformation1 =
      Transformation.new(%{
        type: "regex_extract",
        name: "Transformation",
        parameters: regex_params
      })

    conversion_params = %{
      "field" => "number",
      "sourceType" => "string",
      "targetType" => "integer"
    }

    transformation2 =
      Transformation.new(%{
        type: "conversion",
        name: "Transformation",
        parameters: conversion_params
      })

    transformations = [transformation1, transformation2]
    operations = Transformers.construct(transformations)

    payload = %{
      "thing" => "123abc"
    }

    {:ok, result} = Transformers.perform(operations, payload)

    assert %{"thing" => "123abc", "number" => 1} == result
  end

  test "transform with a nested list structure" do
    parameters = %{
      "sourceField" => "full_name",
      "targetField" => "first_name",
      "regex" => "^(\\w+)"
    }

    transformation1 =
      Transformation.new(%{type: "regex_extract", name: "Transformation", parameters: parameters})

    parameters = %{
      "sourceField" => "full_name",
      "targetField" => "last_name",
      "regex" => "(\\w+)$"
    }

    transformation2 =
      Transformation.new(%{type: "regex_extract", name: "Transformation", parameters: parameters})

    transformations = [transformation1, transformation2]

    operations = Transformers.construct(transformations)

    payload = %{
      "full_name" => "Emily Shire",
      "features" => [
        %{
          "geometry" => %{
            "coordinates" => [
              [
                -93.776684050999961,
                41.617961698000045
              ]
            ]
          }
        }
      ]
    }

    expected = %{
      "full_name" => "Emily Shire",
      "features" => [
        %{
          "geometry" => %{
            "coordinates" => [
              [
                -93.776684050999961,
                41.617961698000045
              ]
            ]
          }
        }
      ],
      "first_name" => "Emily",
      "last_name" => "Shire"
    }

    {:ok, result} = Transformers.perform(operations, payload)

    assert expected == result
  end
end
