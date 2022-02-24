defmodule Transformers.FunctionBuilderTest do
  use ExUnit.Case
  alias Transformers.FunctionBuilder

  test "regex extract function" do
    payload = %{"name" => "elizabeth bennet"}

    first_name_extractor_parameters = %{
      sourceField: "name",
      targetField: "firstName",
      regex: "^(\\w+)"
    }

    first_name_extractor_function =
      FunctionBuilder.build(:regex_extract, first_name_extractor_parameters)

    assert first_name_extractor_function.(payload) ==
             Transformers.RegexExtract.transform(payload, first_name_extractor_parameters)
  end

  test "attempting to build function for unsupported transformation raises error" do
    bad_transformation_type = :ok
    assert {:error, "Unsupported transformation type: #{bad_transformation_type}"} == FunctionBuilder.build(bad_transformation_type, %{
      "foo" => "bar"
    })
  end
end
