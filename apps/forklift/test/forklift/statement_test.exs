defmodule StatementTest do
  use ExUnit.Case
  use Placebo

  alias Forklift.DatasetSchema
  alias Forklift.Statement

  test "build generates a valid statement when given a schema and data" do
    schema = %DatasetSchema{
      id: "rivers",
      columns: [
        {"id", "int"},
        {"name", "string"}
      ]
    }

    data = [
      %{"id" => 1, "name" => "Fred"},
      %{"id" => 2, "name" => "Gred"},
      %{"id" => 3, "name" => "Hred"}
    ]

    result = Statement.build(schema, data)
    expected_result = ~s/insert into rivers (id,name) values (1,'Fred'),(2,'Gred'),(3,'Hred')/

    assert result == expected_result
  end

  test "build generates a valid statement when given a schema and data that are not in the same order" do
    schema = %DatasetSchema{
      id: "rivers",
      columns: [
        {"name", "string"},
        {"id", "int"}
      ]
    }

    data = [
      %{"id" => 9, "name" => "Iom"},
      %{"id" => 8, "name" => "Jom"},
      %{"id" => 7, "name" => "Yom"}
    ]

    result = Statement.build(schema, data)
    expected_result = ~s/insert into rivers (name,id) values ('Iom',9),('Jom',8),('Yom',7)/

    assert result == expected_result
  end
end
