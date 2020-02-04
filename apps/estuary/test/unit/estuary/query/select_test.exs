defmodule Estuary.Query.SelectTest do
  use ExUnit.Case
  use Placebo
  alias Estuary.Query.Select

  @tag capture_log: true
  test "should create the query with * and the table name without any condition with limit all, when only table name is passed no column and no limit is passed" do
    expected_select_statement = "SELECT *\n      FROM any_table\n      \n      \n      LIMIT ALL"

    table_schema = %{
      "table_name" => "any_table"
    }

    actual_select_statement = Select.create_select_statement(table_schema)
    assert expected_select_statement == actual_select_statement
  end

  @tag capture_log: true
  test "should return error, when table name is missing" do
    expected_error = %RuntimeError{message: "Table name missing"}
    table_schema = %{}
    actual_error = Select.create_select_statement(table_schema)
    assert expected_error == actual_error
  end

  @tag capture_log: true
  test "should create the query with * with table name without any condition with limit 1000, when limit is passed" do
    expected_select_statement = "SELECT *\n      FROM any_table\n      \n      \n      LIMIT 1000"

    table_schema = %{
      "table_name" => "any_table",
      "limit" => 1000
    }

    actual_select_statement = Select.create_select_statement(table_schema)
    assert expected_select_statement == actual_select_statement
  end

  @tag capture_log: true
  test "should create the query with the given column names, when column names are passed" do
    expected_select_statement =
      "SELECT any_column_1, any_column_2\n      FROM any_table\n      \n      \n      LIMIT ALL"

    table_schema = %{
      "columns" => ["any_column_1", "any_column_2"],
      "table_name" => "any_table"
    }

    actual_select_statement = Select.create_select_statement(table_schema)
    assert expected_select_statement == actual_select_statement
  end

  @tag capture_log: true
  test "should create the query with where clause conditions, when a condition is passed" do
    expected_select_statement =
      "SELECT any_column_1, any_column_2\n      FROM any_table\n      WHERE\n        any_condition\n      \n      LIMIT ALL"

    table_schema = %{
      "columns" => ["any_column_1", "any_column_2"],
      "table_name" => "any_table",
      "conditions" => ["any_condition"]
    }

    actual_select_statement = Select.create_select_statement(table_schema)
    assert expected_select_statement == actual_select_statement
  end

  @tag capture_log: true
  test "should create the query with where clause conditions with and, when a condition multiple conditions and condition type as and is passed" do
    expected_select_statement =
      "SELECT any_column_1, any_column_2\n      FROM any_table\n      WHERE\n        any_condition_1 AND any_condition_2\n      \n      LIMIT ALL"

    table_schema = %{
      "columns" => ["any_column_1", "any_column_2"],
      "table_name" => "any_table",
      "conditions" => ["any_condition_1", "any_condition_2"],
      "condition_type" => "AND"
    }

    actual_select_statement = Select.create_select_statement(table_schema)
    assert expected_select_statement == actual_select_statement
  end

  @tag capture_log: true
  test "should create the query with where clause conditions with or, when a condition multiple conditions and condition type as or is passed" do
    expected_select_statement =
      "SELECT any_column_1, any_column_2\n      FROM any_table\n      WHERE\n        any_condition_1 OR any_condition_2\n      \n      LIMIT ALL"

    table_schema = %{
      "columns" => ["any_column_1", "any_column_2"],
      "table_name" => "any_table",
      "conditions" => ["any_condition_1", "any_condition_2"],
      "condition_type" => "OR"
    }

    actual_select_statement = Select.create_select_statement(table_schema)

    assert expected_select_statement == actual_select_statement
  end

  @tag capture_log: true
  test "should create the query in the given order when order by and order are passed" do
    expected_select_statement =
      "SELECT any_column_1, any_column_2\n      FROM any_table\n      \n      ORDER BY any_column_1 DESC\n      LIMIT ALL"

    table_schema = %{
      "columns" => ["any_column_1", "any_column_2"],
      "table_name" => "any_table",
      "order_by" => "any_column_1",
      "order" => "DESC"
    }

    actual_select_statement = Select.create_select_statement(table_schema)
    assert expected_select_statement == actual_select_statement
  end

  @tag capture_log: true
  test "should create the query in ascending order when order is missing" do
    expected_select_statement =
      "SELECT any_column_1, any_column_2\n      FROM any_table\n      \n      ORDER BY any_column_1 ASC\n      LIMIT ALL"

    table_schema = %{
      "columns" => ["any_column_1", "any_column_2"],
      "table_name" => "any_table",
      "order_by" => "any_column_1"
    }

    actual_select_statement = Select.create_select_statement(table_schema)
    assert expected_select_statement == actual_select_statement
  end

  @tag capture_log: true
  test "should create the query without order when order by is missing" do
    expected_select_statement =
      "SELECT any_column_1, any_column_2\n      FROM any_table\n      \n      \n      LIMIT ALL"

    table_schema = %{
      "columns" => ["any_column_1", "any_column_2"],
      "table_name" => "any_table",
      "order" => "ASC"
    }

    actual_select_statement = Select.create_select_statement(table_schema)
    assert expected_select_statement == actual_select_statement
  end
end
