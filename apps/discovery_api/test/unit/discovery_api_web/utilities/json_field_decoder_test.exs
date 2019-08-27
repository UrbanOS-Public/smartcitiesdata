defmodule DiscoveryApiWeb.JsonFieldDecoderTest do
  use ExUnit.Case
  use Placebo
  import Checkov
  alias DiscoveryApiWeb.Utilities.JsonFieldDecoder

  describe "ensure_decoded/2" do
    data_test "returns based on schema assigned to it" do
      actual_value = JsonFieldDecoder.ensure_decoded(input, schema)

      assert actual_value |> Enum.into([]) == expected_output

      where([
        [:expected_output, :input, :schema],
        [
          [%{"id" => 1, "name" => "robert"}, %{"id" => 2, "name" => "tony"}],
          [%{"id" => 1, "name" => "robert"}, %{"id" => 2, "name" => "tony"}],
          [
            %{name: "id", type: "integer"},
            %{name: "name", type: "string"}
          ]
        ],
        [
          [
            %{"id" => 1, "name" => %{"name" => "robert"}},
            %{"id" => 2, "name" => %{"name" => "tony"}}
          ],
          [
            %{"id" => 1, "name" => "{\"name\": \"robert\"}"},
            %{"id" => 2, "name" => "{\"name\": \"tony\"}"}
          ],
          [
            %{name: "id", type: "integer"},
            %{name: "name", type: "json"}
          ]
        ],
        [
          [
            %{"id" => 1, "name" => "{\"name\": \"robert\"}"},
            %{"id" => 2, "name" => "{\"name\": \"tony\"}"}
          ],
          [
            %{"id" => 1, "name" => "{\"name\": \"robert\"}"},
            %{"id" => 2, "name" => "{\"name\": \"tony\"}"}
          ],
          []
        ],
        [
          [
            %{
              "id" => 1,
              "bins" => %{
                "bins" => %{"day" => %{}, "hour" => %{}, "minute" => %{}},
                "streets" => %{"day" => %{}, "hour" => %{}, "minute" => %{}}
              }
            },
            %{
              "id" => 2,
              "bins" => %{
                "bins" => %{"day" => %{}, "hour" => %{}, "minute" => %{}},
                "streets" => %{"day" => %{}, "hour" => %{}, "minute" => %{}}
              }
            }
          ],
          [
            %{
              "id" => 1,
              "bins" => "{\"bins\":{\"day\":{},\"hour\":{},\"minute\":{}},\"streets\":{\"day\":{},\"hour\":{},\"minute\":{}}}"
            },
            %{
              "id" => 2,
              "bins" => "{\"bins\":{\"day\":{},\"hour\":{},\"minute\":{}},\"streets\":{\"day\":{},\"hour\":{},\"minute\":{}}}"
            }
          ],
          [
            %{name: "id", type: "integer"},
            %{name: "bins", type: "json"}
          ]
        ]
      ])
    end
  end
end
