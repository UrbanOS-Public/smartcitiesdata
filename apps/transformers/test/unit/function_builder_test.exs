defmodule Transformers.FunctionBuilderTest do
  use ExUnit.Case

  test "regex extract function" do
    payload = %{"name" => "elizabeth bennet"}

    first_name_extractor_parameters = %{
      sourceField: "name",
      targetField: "firstName",
      regex: "^(\\w+)"
    }

    first_name_extractor_function =
      Transformers.FunctionBuilder.build(:regex_extract, first_name_extractor_parameters)

    assert first_name_extractor_function.(payload) ==
             Transformers.RegexExtract.transform(payload, first_name_extractor_parameters)
  end

  test "attempting to build function for unsupported transformation raises error" do
    assert_raise RuntimeError,
                 "Unsupported transformation type: unsupported_transformation",
                 fn -> Transformers.FunctionBuilder.build(:unsupported_transformation, %{}) end
  end
end
