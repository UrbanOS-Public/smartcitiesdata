defmodule Transformers.FunctionBuilderTest do
  use ExUnit.Case

  test "given a list of one transformation, the payload matches that of what is expected" do
    payload = %{"name" => "elizabeth bennet"}

    first_name_extractor_parameters = %{
      sourceField: "name",
      targetField: "firstName",
      regex: "^(\\w+)"
    }

    first_name_extractor_function =
      Transformers.FunctionBuilder.build(:regex_extract, first_name_extractor_parameters)

    {:ok, resultant_payload} = Transformers.performTransformations([first_name_extractor_function], payload)

    assert {:ok, resultant_payload} == Transformers.RegexExtract.transform(payload, first_name_extractor_parameters)
  end

  test "multiple transformations return a payload that matches multiple manual transformation" do
    payload = %{"name" => "elizabeth bennet"}

    first_name_extractor_parameters = %{
      sourceField: "name",
      targetField: "firstName",
      regex: "^(\\w+)"
    }

    first_letter_extractor = %{
      sourceField: "firstName",
      targetField: "firstLetter",
      regex: "^(\\w)"
    }

    first_name_extractor_function =
      Transformers.FunctionBuilder.build(:regex_extract, first_name_extractor_parameters)
    first_letter_extractor_function =
      Transformers.FunctionBuilder.build(:regex_extract, first_letter_extractor)

    {:ok, resultant_payload} = Transformers.performTransformations([first_name_extractor_function, first_letter_extractor_function], payload)

    {:ok, firstNamePayload} = Transformers.RegexExtract.transform(payload, first_name_extractor_parameters)
    {:ok, firstLetterPayload} = Transformers.RegexExtract.transform(firstNamePayload, first_letter_extractor)

    assert {:ok, resultant_payload} = {:ok, firstLetterPayload}
  end

  test "when any operation fails, execution halts and error is returned" do
    payload = %{"phone" => "elizabeth bennet"}

    first_name_extractor_parameters = %{
      sourceField: "name",
      targetField: "firstName",
      regex: "^(\\w+)"
    }

    first_letter_extractor = %{
      sourceField: "firstName",
      targetField: "firstLetter",
      regex: "^(\\w)"
    }

    first_name_extractor_function =
      Transformers.FunctionBuilder.build(:regex_extract, first_name_extractor_parameters)
    first_letter_extractor_function =
      Transformers.FunctionBuilder.build(:regex_extract, first_letter_extractor)

    {:error, reason} = Transformers.performTransformations([first_name_extractor_function, first_letter_extractor_function], payload)

    assert resultant_payload = "Error name not found"
  end
end
