defmodule Transformers.MultiplicationTest do
  use ExUnit.Case
  use Checkov

  alias Transformers.Multiplication

  describe "The multiplication transform" do
    test "returns payload with target field of the input variable multiplied by a constant" do
      params = %{
        "multiplicands" => ["input_number", 5],
        "targetField" => "output_number"
      }

      message_payload = %{"input_number" => 8}

      {:ok, transformed_payload} = Transformers.Multiplication.transform(message_payload, params)

      {:ok, actual_target_field} = Map.fetch(transformed_payload, "output_number")
      assert actual_target_field == 40
    end

    test "returns payload with target field with a specified target field name" do
      params = %{
        "multiplicands" => ["input_number", 5],
        "targetField" => "some_other_output_number"
      }

      message_payload = %{"input_number" => 8}

      {:ok, transformed_payload} = Transformers.Multiplication.transform(message_payload, params)

      {:ok, actual_target_field} = Map.fetch(transformed_payload, "some_other_output_number")
      assert actual_target_field == 40
    end

    test "returns payload with a different multiplicands" do

      params = %{
        "multiplicands" => ["some_other_input_number", 9],
        "targetField" => "some_other_output_number"
      }

      message_payload = %{"some_other_input_number" => 3}

      {:ok, transformed_payload} = Transformers.Multiplication.transform(message_payload, params)

      {:ok, actual_target_field} = Map.fetch(transformed_payload, "some_other_output_number")
      assert actual_target_field == 27
    end

    test "returns payload with multiple multiplicands fields" do

      params = %{
        "multiplicands" => ["some_other_input_number", "foo"],
        "targetField" => "some_other_output_number"
      }

      message_payload = %{"some_other_input_number" => 3, "foo" => 6}

      {:ok, transformed_payload} = Transformers.Multiplication.transform(message_payload, params)

      {:ok, actual_target_field} = Map.fetch(transformed_payload, "some_other_output_number")
      assert actual_target_field == 18
    end

    test "returns an error if a field in the multiplicand doesnt exist" do

      params = %{
        "multiplicands" => ["some_other_input_number", "bar"],
        "targetField" => "some_other_output_number"
      }

      message_payload = %{"some_other_input_number" => 3}

      {:error, reason } = Transformers.Multiplication.transform(message_payload, params)

      assert reason == "Missing field in payload: bar"
    end

    test "ignores additional payload fields that are not in the multiplicands" do

      params = %{
        "multiplicands" => ["some_other_input_number", 9],
        "targetField" => "some_other_output_number"
      }

      message_payload = %{"input_number" => 8, "some_other_input_number" => 3}

      {:ok, transformed_payload} = Transformers.Multiplication.transform(message_payload, params)

      {:ok, actual_target_field} = Map.fetch(transformed_payload, "some_other_output_number")
      assert actual_target_field == 27
    end

    test "returns an error if a field in the multiplicand is not a number" do

      params = %{
        "multiplicands" => ["some_other_input_number", "invalid"],
        "targetField" => "some_other_output_number"
      }

      message_payload = %{"some_other_input_number" => 3, "invalid" => "not a number"}

      {:error, reason } = Transformers.Multiplication.transform(message_payload, params)

      assert reason == "multiplicand field not a number: invalid"
    end


  #   test "returns payload with null value in target field if no regex match" do
  #     params = %{
  #       "sourceField" => "phone_number",
  #       "targetField" => "area_code",
  #       "regex" => "bananas"
  #     }

  #     message_payload = %{"phone_number" => "(555) 123-4567"}

  #     {:ok, transformed_payload} = Transformers.RegexExtract.transform(message_payload, params)

  #     {:ok, actual_target_field} = Map.fetch(transformed_payload, "area_code")
  #     assert actual_target_field == nil
  #   end

  #   test "returns payload with overwritten target field" do
  #     params = %{
  #       "sourceField" => "full_name",
  #       "targetField" => "first_name",
  #       "regex" => "^(\\w+)"
  #     }

  #     message_payload = %{"full_name" => "Jane Austen", "first_name" => "n/a"}

  #     {:ok, transformed_payload} = Transformers.RegexExtract.transform(message_payload, params)

  #     {:ok, actual_target_field} = Map.fetch(transformed_payload, "first_name")
  #     assert actual_target_field == "Jane"
  #   end

  #   test "returns an error if the specified source field does not exist" do
  #     params = %{
  #       "sourceField" => "source_field",
  #       "targetField" => "target_field",
  #       "regex" => "^\((\d{3})\)"
  #     }

  #     message_payload = %{"some_other_field" => "not what you were expecting"}

  #     {:error, reason} = Transformers.RegexExtract.transform(message_payload, params)

  #     assert reason == "Missing field in payload: source_field"
  #   end

  #   test "returns an error if the regex does not compile" do
  #     params = %{
  #       "sourceField" => "source_field",
  #       "targetField" => "target_field",
  #       "regex" => "^\((\d{3})"
  #     }

  #     message_payload = %{"source_field" => "field"}

  #     {:error, reason} = Transformers.RegexExtract.transform(message_payload, params)

  #     assert reason == %{"regex" => "Invalid regular expression: missing ) at index 8"}
  #   end

  #   test "if source and target field are the same overwrite original value" do
  #     params = %{
  #       "sourceField" => "name",
  #       "targetField" => "name",
  #       "regex" => "^(\\w+)"
  #     }

  #     message_payload = %{"name" => "Emily Wilkenson"}

  #     {:ok, transformed_payload} = Transformers.RegexExtract.transform(message_payload, params)

  #     assert transformed_payload == %{"name" => "Emily"}
  #   end
   end

   describe "validate/1" do
  #   test "returns :ok if all parameters are present and valid" do
  #     parameters = %{
  #       "sourceField" => "phone_number",
  #       "targetField" => "area_code",
  #       "regex" => "^\\((\\d{3})\\)"
  #     }

  #     {:ok, [source_field, target_field, regex]} = RegexExtract.validate(parameters)

  #     assert source_field == parameters["sourceField"]
  #     assert target_field == parameters["targetField"]
  #     assert regex == Regex.compile!(parameters["regex"])
  #   end

     data_test "when missing parameter #{parameter} return error" do
       parameters =
         %{
           "multiplicands" => [1,2],
           "targetField" => "area_code"
         }
         |> Map.delete(parameter)

       {:error, reason } = Transformers.Multiplication.transform(%{}, parameters)

       assert reason == %{"#{parameter}" => "Missing or empty field"}

       where(parameter: ["multiplicands", "targetField"])
     end

  #   test "returns error when regex is invalid" do
  #     params = %{
  #       "sourceField" => "source_field",
  #       "targetField" => "target_field",
  #       "regex" => "^\((\d{3})"
  #     }

  #     {:error, reason} = RegexExtract.validate(params)

  #     assert reason == %{"regex" => "Invalid regular expression: missing ) at index 8"}
     end
end
