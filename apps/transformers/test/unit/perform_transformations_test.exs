defmodule Transformers.PerformTest do
  use ExUnit.Case

  alias Transformers
  alias Transformers.OperationBuilder

  test "given a list of one transformation, the payload matches that of what is expected" do
    payload = %{"name" => "elizabeth bennet"}

    first_name_extractor_parameters = %{
      sourceField: "name",
      targetField: "firstName",
      regex: "^(\\w+)"
    }

    first_name_extractor_function =
      OperationBuilder.build("regex_extract", first_name_extractor_parameters)

    {:ok, resultant_payload} =
      Transformers.perform([first_name_extractor_function], payload)

    assert {:ok, resultant_payload} ==
             Transformers.RegexExtract.transform(payload, first_name_extractor_parameters)
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
      OperationBuilder.build("regex_extract", first_name_extractor_parameters)

    first_letter_extractor_function =
      OperationBuilder.build("regex_extract", first_letter_extractor)

    {:ok, resultant_payload} =
      Transformers.perform(
        [first_name_extractor_function, first_letter_extractor_function],
        payload
      )

    {:ok, first_name_payload} =
      Transformers.RegexExtract.transform(payload, first_name_extractor_parameters)

    assert Transformers.RegexExtract.transform(first_name_payload, first_letter_extractor) == {:ok, resultant_payload}
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
      OperationBuilder.build("regex_extract", first_name_extractor_parameters)

    first_letter_extractor_function =
      OperationBuilder.build("regex_extract", first_letter_extractor)

    {:error, _reason} =
      Transformers.perform(
        [first_name_extractor_function, first_letter_extractor_function],
        payload
      )

    assert resultant_payload = "Error name not found"
  end

  test "when provided an empty opsList, the initial payload is returned" do
    payload = %{name: "ben"}
    {:ok, result} = Transformers.perform([], payload)
    assert result == payload
  end

  test "what happens when opsList includes an error" do
    payload = %{name: "ben"}
    transformations = [{:error, "kaboom"}]
    result = Transformers.perform(transformations, payload)
    assert :error == elem(result, 0)
  end
end
