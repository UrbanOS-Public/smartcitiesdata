defmodule Transformers.OperationBuilderTest do
  use ExUnit.Case
  alias Transformers.OperationBuilder

  test "regex extract function" do
    payload = %{"name" => "elizabeth bennet"}

    first_name_extractor_parameters = %{
      "sourceField" => "name",
      "targetField" => "firstName",
      "regex" => "^(\\w+)"
    }

    first_name_extractor_function =
      OperationBuilder.build("regex_extract", first_name_extractor_parameters)

    first_name_extractor_validation =
      OperationBuilder.validate("regex_extract", first_name_extractor_parameters)

    assert first_name_extractor_function.(payload) ==
             Transformers.RegexExtract.transform(payload, first_name_extractor_parameters)

    assert first_name_extractor_validation ==
             Transformers.RegexExtract.validate(first_name_extractor_parameters)
  end

  test "attempting to build function for unsupported transformation raises error" do
    bad_transformation_type = :ok

    assert {:error, "Unsupported transformation type: #{bad_transformation_type}"} ==
             OperationBuilder.build(bad_transformation_type, %{
               "foo" => "bar"
             })

    assert {:error, "Unsupported transformation validation type: #{bad_transformation_type}"} ==
             OperationBuilder.validate(bad_transformation_type, %{
               "foo" => "bar"
             })
  end

  test "type conversion function" do
    payload = %{"number" => "1"}

    parameters = %{
      "field" => "number",
      "sourceType" => "string",
      "targetType" => "integer"
    }

    function = OperationBuilder.build("conversion", parameters)
    validation = OperationBuilder.validate("conversion", parameters)

    assert function.(payload) == Transformers.TypeConversion.transform(payload, parameters)
    assert validation == Transformers.TypeConversion.validate(parameters)
  end

  test "datetime function" do
    params = %{
      "sourceField" => "date1",
      "targetField" => "date2",
      "sourceFormat" => "{YYYY}-{0M}-{D} {h24}:{m}",
      "targetFormat" => "{Mfull} {D}, {YYYY} {h12}:{m} {AM}"
    }

    payload = %{"date1" => "2022-02-28 16:53"}

    function = OperationBuilder.build("datetime", params)
    validation = OperationBuilder.validate("datetime", params)

    assert function.(payload) == Transformers.DateTime.transform(payload, params)
    assert validation == Transformers.DateTime.validate(params)
  end

  test "regex replace function" do
    params = %{
      "sourceField" => "arbitrary",
      "regex" => "abc",
      "replacement" => "123"
    }

    payload = %{"arbitrary" => "abc"}

    function = OperationBuilder.build("regex_replace", params)
    validation = OperationBuilder.validate("regex_replace", params)

    assert function.(payload) == Transformers.RegexReplace.transform(payload, params)
    assert validation == Transformers.RegexReplace.validate(params)
  end

  test "concatenation function" do
    params = %{
      "sourceFields" => "greeting, target",
      "targetField" => "salutation",
      "separator" => " "
    }

    payload = %{"greeting" => "Hello", "target" => "World"}

    function = OperationBuilder.build("concatenation", params)
    validation = OperationBuilder.validate("concatenation", params)

    assert function.(payload) == Transformers.Concatenation.transform(payload, params)
    assert validation == Transformers.Concatenation.validate(params)
  end

  test "remove function" do
    params = %{
      "sourceField" => "dead"
    }

    payload = %{
      "dead" => "so long farewell"
    }

    function = OperationBuilder.build("remove", params)
    validation = OperationBuilder.validate("remove", params)

    assert function.(payload) == Transformers.Remove.transform(payload, params)
    assert validation == Transformers.Remove.validate(params)
  end

  test "arithmetic add function" do
    params = %{
      "targetField" => "target",
      "addends" => ["one", "two", 3]
    }

    payload = %{
      "one" => 1,
      "two" => 2
    }

    function = OperationBuilder.build("add", params)
    validation = OperationBuilder.validate("add", params)

    assert function.(payload) == Transformers.Add.transform(payload, params)
    assert validation == Transformers.Add.validate(params)
  end

  test "arithmetic subtract function" do
    params = %{
      "minuend" => "two",
      "subtrahends" => ["one", 1],
      "targetField" => "target"
    }

    payload = %{
      "one" => 1,
      "two" => 2
    }

    function = OperationBuilder.build("subtract", params)
    validation = OperationBuilder.validate("subtract", params)

    assert function.(payload) == Transformers.Subtract.transform(payload, params)
    assert validation == Transformers.Subtract.validate(params)
  end

  test "multiplication function" do
    params = %{
      "targetField" => "target",
      "multiplicands" => ["one", "two", 3]
    }

    payload = %{
      "one" => 1,
      "two" => 2
    }

    function = OperationBuilder.build("multiplication", params)
    validation = OperationBuilder.validate("multiplication", params)

    assert function.(payload) == Transformers.Multiplication.transform(payload, params)
    assert validation == Transformers.Multiplication.validate(params)
  end

  test "division function" do
    params = %{
      "targetField" => "target",
      "divisor" => "two",
      "dividend" => "one"
    }

    payload = %{
      "one" => 1,
      "two" => 2
    }

    function = OperationBuilder.build("division", params)
    validation = OperationBuilder.validate("division", params)

    assert function.(payload) == Transformers.Division.transform(payload, params)
    assert validation == Transformers.Division.validate(params)
  end
end
