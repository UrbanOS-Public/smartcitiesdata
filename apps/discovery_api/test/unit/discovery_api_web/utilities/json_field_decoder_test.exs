defmodule DiscoveryApiWeb.JsonFieldDecoderTest do
  use ExUnit.Case
  use Placebo
  alias JsonFieldDecoder

  describe "has_json_fields/2" do
    test "has_json_fields/2 returns value when schema has no json fields" do
      no_json_schema = [
        %{description: "a number", name: "number", type: "integer"},
        %{description: "another number", name: "number2", type: "integer"},
        %{description: "and yet another number", name: "number3", type: "integer"}
      ]

      value = [[1, 2, 3], [4, 5, 6]]

      result = JsonFieldDecoder.has_json_fields(no_json_schema, value)

      assert result == value
    end

    test "has_json_fields/2 returns decoded json when schema has json fields" do
      json_schema = [
        %{description: "a json string", name: "json_string", type: "json"},
        %{description: "a json string", name: "json_string2", type: "json"}
      ]

      value = [
        [~s|{"json_string":"an encoded json string"}|, ~s|{"json_string":"an encoded json string"}|],
        ["{\"json_string\":\"an encoded json string\"}", "{\"json_string\":\"an encoded json string\"}"]
      ]

      expected_value = [
        [%{"json_string" => "an encoded json string"}, %{"json_string" => "an encoded json string"}],
        [%{"json_string" => "an encoded json string"}, %{"json_string" => "an encoded json string"}]
      ]

      result = JsonFieldDecoder.has_json_fields(json_schema, value)

      assert result == expected_value
    end

    test "has_json_fields/2 only decodes json fields" do
      no_json_schema = [
        %{description: "a number", name: "number", type: "integer"},
        %{description: "a json string", name: "json_field", type: "json"}
      ]

      value = [[1, "{\"bins\":{\"day\":{},\"hour\":{},\"minute\":{}},\"streets\":{\"day\":
      {},\"hour\":{},\"minute\":{}}}"]]

      expected_value = [
        [1, %{"bins" => %{"day" => %{}, "hour" => %{}, "minute" => %{}}, "streets" => %{"day" => %{}, "hour" => %{}, "minute" => %{}}}]
      ]

      result = JsonFieldDecoder.has_json_fields(no_json_schema, value)

      assert result == expected_value
    end
  end
end
