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

  test "simple transform with list of more than 10 elements" do
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
                -93.79152224399996,
                41.61494825200003
              ],
              [
                -93.79150531999994,
                41.61501428300005
              ],
              [
                -93.79140579199998,
                41.61557707600008
              ],
              [
                -93.79134543099997,
                41.61578244400005
              ],
              [
                -93.79128030499999,
                41.615977213000065
              ],
              [
                -93.79120089199995,
                41.616140173000076
              ],
              [
                -93.79107900999998,
                41.61629616500005
              ],
              [
                -93.79055801099997,
                41.61681760700003
              ],
              [
                -93.79013560199996,
                41.617246805000036
              ],
              [
                -93.78983055299994,
                41.61756248000006
              ],
              [
                -93.78968061399996,
                41.61777161300006
              ],
              [
                -93.78959638299995,
                41.61791335600003
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
                -93.79152224399996,
                41.61494825200003
              ],
              [
                -93.79150531999994,
                41.61501428300005
              ],
              [
                -93.79140579199998,
                41.61557707600008
              ],
              [
                -93.79134543099997,
                41.61578244400005
              ],
              [
                -93.79128030499999,
                41.615977213000065
              ],
              [
                -93.79120089199995,
                41.616140173000076
              ],
              [
                -93.79107900999998,
                41.61629616500005
              ],
              [
                -93.79055801099997,
                41.61681760700003
              ],
              [
                -93.79013560199996,
                41.617246805000036
              ],
              [
                -93.78983055299994,
                41.61756248000006
              ],
              [
                -93.78968061399996,
                41.61777161300006
              ],
              [
                -93.78959638299995,
                41.61791335600003
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
