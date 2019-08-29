defmodule DiscoveryApiWeb.JsonFieldDecoderTest do
  use ExUnit.Case
  use Placebo
  import Checkov
  alias DiscoveryApiWeb.Utilities.JsonFieldDecoder

  describe "ensure_decoded/2" do
    data_test "returns based on schema assigned to it" do
      actual_value = JsonFieldDecoder.decode_one_datum(schema, input)

      assert actual_value == expected_output

      where([
        [:expected_output, :input, :schema],
        [
          %{"id" => 2, "name" => "tony"},
          %{"id" => 2, "name" => "tony"},
          [
            %{name: "id", type: "integer"},
            %{name: "name", type: "string"}
          ]
        ],
        [
          %{"id" => 1, "name" => %{"name" => "robert"}},
          %{"id" => 1, "name" => "{\"name\": \"robert\"}"},
          [
            %{name: "id", type: "integer"},
            %{name: "name", type: "json"}
          ]
        ],
        [
          %{"id" => 1, "name" => "{\"name\": \"robert\"}"},
          %{"id" => 1, "name" => "{\"name\": \"robert\"}"},
          []
        ],
        [
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
        ]
      ])
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
