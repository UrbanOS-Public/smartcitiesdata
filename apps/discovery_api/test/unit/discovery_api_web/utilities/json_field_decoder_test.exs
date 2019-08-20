defmodule DiscoveryApiWeb.JsonFieldDecoderTest do
  use ExUnit.Case
  use Placebo
  import Checkov
  alias JsonFieldDecoder

  describe "ensure_decoded/2" do
    data_test "ensure_decoded/2 returns based on schema assigned to it" do
      actual_value = JsonFieldDecoder.ensure_decoded(schema, input)

      assert actual_value == expected_output

      where([
        [:expected_output, :input, :schema],
        # no json in schema
        [
          [%{"id" => 1, "name" => "robert", "age" => 22}, %{"id" => 2, "name" => "tony", "age" => 3}],
          [%{"id" => 1, "name" => "robert", "age" => 22}, %{"id" => 2, "name" => "tony", "age" => 3}],
          [
            %{description: "a number", name: "id", type: "integer"},
            %{description: "another number", name: "name", type: "string"},
            %{description: "and yet another number", name: "age", type: "integer"}
          ]
        ],
        # json in schema
        [
          [
            %{"id" => 1, "name" => %{"name" => "robert"}, "age" => 22},
            %{"id" => 2, "name" => %{"name" => "tony"}, "age" => 3}
          ],
          [
            %{"id" => 1, "name" => "{\"name\": \"robert\"}", "age" => 22},
            %{"id" => 2, "name" => "{\"name\": \"tony\"}", "age" => 3}
          ],
          [
            %{description: "a number", name: "id", type: "integer"},
            %{description: "a json string", name: "name", type: "json"},
            %{description: "and yet another number", name: "age", type: "integer"}
          ]
        ],
        # no schema
        [
          [
            %{"id" => 1, "name" => "{\"name\": \"robert\"}", "age" => 22},
            %{"id" => 2, "name" => "{\"name\": \"tony\"}", "age" => 3}
          ],
          [
            %{"id" => 1, "name" => "{\"name\": \"robert\"}", "age" => 22},
            %{"id" => 2, "name" => "{\"name\": \"tony\"}", "age" => 3}
          ],
          []
        ],
        # nested json in schema w/ mutliple columns
        [
          [
            %{
              "id" => 1,
              "name" => %{"name" => "robert"},
              "bins" => %{
                "bins" => %{"day" => %{}, "hour" => %{}, "minute" => %{}},
                "streets" => %{"day" => %{}, "hour" => %{}, "minute" => %{}}
              }
            },
            %{
              "id" => 2,
              "name" => %{"name" => "tony"},
              "bins" => %{
                "bins" => %{"day" => %{}, "hour" => %{}, "minute" => %{}},
                "streets" => %{"day" => %{}, "hour" => %{}, "minute" => %{}}
              }
            }
          ],
          [
            %{
              "id" => 1,
              "name" => "{\"name\": \"robert\"}",
              "bins" => "{\"bins\":{\"day\":{},\"hour\":{},\"minute\":{}},\"streets\":{\"day\":{},\"hour\":{},\"minute\":{}}}"
            },
            %{
              "id" => 2,
              "name" => "{\"name\": \"tony\"}",
              "bins" => "{\"bins\":{\"day\":{},\"hour\":{},\"minute\":{}},\"streets\":{\"day\":{},\"hour\":{},\"minute\":{}}}"
            }
          ],
          [
            %{description: "a number", name: "id", type: "integer"},
            %{description: "a json string", name: "name", type: "json"},
            %{description: "and yet another number", name: "bins", type: "json"}
          ]
        ]
      ])
    end
  end
end
