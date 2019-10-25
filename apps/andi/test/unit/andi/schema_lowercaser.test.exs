defmodule Andi.SchemaDowncaserTest do
  use ExUnit.Case
  alias Andi.SchemaDowncaser
  alias SmartCity.TestDataGenerator, as: TDG

  test "when schema is nil pass back nil" do
    result = SchemaDowncaser.downcase_schema(nil)
    assert is_nil(result)
  end

  test "when schema is not a list pass back the parameter" do
    expected = <<123>>
    result = SchemaDowncaser.downcase_schema(expected)
    assert result == expected
  end

  test "sets all column names in the schema to lower case" do
    schema = [
      %{
        "name" => "UPPERCASE",
        "another_field" => "ANOTHER"
      },
      %{
        "name" => "HElloW",
        "another_field" => "ANOTHER1"
      }
    ]

    expected = [
      %{
        "name" => "uppercase",
        "another_field" => "ANOTHER"
      },
      %{
        "name" => "hellow",
        "another_field" => "ANOTHER1"
      }
    ]

    assert expected == SchemaDowncaser.downcase_schema(schema)
  end
end
