defmodule DiscoveryApiWeb.JsonFieldDecoderTest do
  use ExUnit.Case
  use Placebo
  import Checkov
  alias DiscoveryApiWeb.Utilities.JsonFieldDecoder

  describe "decode_one_datum/2" do
    data_test "returns based on schema assigned to it - #{description}" do
      actual_value = JsonFieldDecoder.decode_one_datum(schema, input)

      assert actual_value == expected_output

      where([
        [:description, :expected_output, :input, :schema],
        [
          "no json in the schema returns values given",
          %{"id" => 2, "name" => "tony"},
          %{"id" => 2, "name" => "tony"},
          [
            %{name: "id", type: "integer"},
            %{name: "name", type: "string"}
          ]
        ],
        [
          "json field is decoded",
          %{"id" => 1, "name" => %{"name" => "robert"}},
          %{"id" => 1, "name" => "{\"name\": \"robert\"}"},
          [
            %{name: "id", type: "integer"},
            %{name: "name", type: "json"}
          ]
        ],
        [
          "no schema returns values given",
          %{"id" => 1, "name" => "{\"name\": \"robert\"}"},
          %{"id" => 1, "name" => "{\"name\": \"robert\"}"},
          []
        ],
        [
          "json fields with nested json are decoded",
          %{
            "id" => 1,
            "bins" => %{
              "bins" => %{"day" => %{}, "hour" => %{}, "minute" => %{}},
              "streets" => %{"day" => %{}, "hour" => %{}, "minute" => %{}}
            }
          },
          %{
            "id" => 1,
            "bins" => "{\"bins\":{\"day\":{},\"hour\":{},\"minute\":{}},\"streets\":{\"day\":{},\"hour\":{},\"minute\":{}}}"
          },
          [
            %{name: "id", type: "integer"},
            %{name: "bins", type: "json"}
          ]
        ],
        [
          "unknown json field in schema returns values given",
          %{"id" => 1},
          %{"id" => 1},
          [
            %{name: "not_found", type: "json"}
          ]
        ],
        [
          "mixed cased key in schema is downcased to match lowercase database column name",
          %{"mixedcasekey" => %{"name" => "billy"}},
          %{"mixedcasekey" => "{\"name\": \"billy\"}"},
          [
            %{name: "mIxEdCaSeKeY", type: "json"}
          ]
        ]
      ])

      _suppress_warning = description
    end

    test "raises on invalid json" do
      input = %{"id" => 1, "name" => "{\"name\" \"robert\"}"}

      schema = [
        %{name: "id", type: "integer"},
        %{name: "name", type: "json"}
      ]

      assert_raise(Jason.DecodeError, fn -> JsonFieldDecoder.decode_one_datum(schema, input) end)
    end
  end
end
