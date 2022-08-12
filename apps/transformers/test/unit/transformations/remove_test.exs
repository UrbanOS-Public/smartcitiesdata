defmodule Transformers.RemoveTest do
  use ExUnit.Case

  alias Transformers.Remove

  describe "transform/2" do
    test "if source field not specified, return error" do
      payload = %{
        "dead_field" => "goodbye"
      }

      parameters = %{}

      {:error, reason} = Remove.transform(payload, parameters)

      assert reason == %{"sourceField" => "Missing or empty field"}
    end

    test "if source field not on payload, return error" do
      payload = %{
        "undead_field" => "goodbye"
      }

      parameters = %{
        "sourceField" => "dead_field"
      }

      {:error, reason} = Remove.transform(payload, parameters)

      assert reason == "Missing field in payload: dead_field"
    end

    test "remove specified field" do
      payload = %{
        "good_field" => "hello",
        "dead_field" => "goodbye"
      }

      parameters = %{
        "sourceField" => "dead_field"
      }

      {:ok, result} = Remove.transform(payload, parameters)

      assert result == %{"good_field" => "hello"}
    end
  end

  describe "validate/1" do
    test "returns :ok if all parameters are present" do
      parameters = %{
        "sourceField" => "dead_field"
      }

      {:ok, source_field} = Remove.validate(parameters)

      assert source_field == parameters["sourceField"]
    end

    test "when missing parameter sourceField return error" do
      parameters =
        %{
          "sourceField" => "dead_field"
        }
        |> Map.delete("sourceField")

      {:error, reason} = Remove.validate(parameters)

      assert reason == %{"sourceField" => "Missing or empty field"}
    end

    test "when empty sourceField return error" do
      parameters =
        %{
          "sourceField" => ""
        }

      {:error, reason} = Remove.validate(parameters)

      assert reason == %{"sourceField" => "Missing or empty field"}
    end

    test "when whitespace sourceField return error" do
      parameters =
        %{
          "sourceField" => "   "
        }

      {:error, reason} = Remove.validate(parameters)

      assert reason == %{"sourceField" => "Missing or empty field"}
    end
  end

  describe "fields/0" do
    test "describes the fields needed for transformation" do
      expected_fields = [
        %{
          field_name: "sourceField",
          field_type: "string",
          field_label: "Field to Remove",
          options: nil
        }
      ]

      assert Remove.fields() == expected_fields
    end
  end
end
