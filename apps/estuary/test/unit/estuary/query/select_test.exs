defmodule Estuary.Query.SelectTest do
  use ExUnit.Case
  use Placebo
  alias Estuary.Query.Select

  describe "should get the data from the given table" do
    @expected_events [
      %{
        "author" => "Author-2020-01-21 23:29:20.171519Z",
        "create_ts" => 1_579_649_360,
        "data" => "Data-2020-01-21 23:29:20.171538Z",
        "type" => "Type-2020-01-21 23:29:20.171543Z"
      },
      %{
        "author" => "Author-2020-01-21 23:25:52.522084Z",
        "create_ts" => 1_579_649_152,
        "data" => "Data-2020-01-21 23:25:52.522107Z",
        "type" => "Type-2020-01-21 23:25:52.522111Z"
      }
    ]

    @tag capture_log: true
    test "should return the events for the given limit on the given condition in descending order" do
      table_schema = %{
        "columns" => ["author", "create_ts", "data", "type"],
        "table_name" => "any_table",
        "order_by" => "create_ts",
        "order" => "DESC",
        "limit" => 1000
      }

      allow(Prestige.new_session(any()), return: :do_not_care)
      allow(Prestige.query!(any(), any()), return: :do_not_care)
      allow(Prestige.Result.as_maps(any()), return: @expected_events)
      assert {:ok, @expected_events} == Select.select_table(table_schema)
    end

    @tag capture_log: true
    test "should return all the events when limit is not passed on the given condition in descending order" do
      table_schema = %{
        "columns" => ["author", "create_ts", "data", "type"],
        "table_name" => "any_table",
        "order_by" => "create_ts",
        "order" => "DESC"
      }

      allow(Prestige.new_session(any()), return: :do_not_care)
      allow(Prestige.query!(any(), any()), return: :do_not_care)
      allow(Prestige.Result.as_maps(any()), return: @expected_events)
      assert {:ok, @expected_events} == Select.select_table(table_schema)
    end

    @tag capture_log: true
    test "should return all the columns when column names are not passed on the given condition" do
      table_schema = %{
        "table_name" => "any_table",
        "order_by" => "create_ts",
        "order" => "DESC",
        "limit" => 1000
      }

      allow(Prestige.new_session(any()), return: :do_not_care)
      allow(Prestige.query!(any(), any()), return: :do_not_care)
      allow(Prestige.Result.as_maps(any()), return: @expected_events)
      assert {:ok, @expected_events} == Select.select_table(table_schema)
    end

    @tag capture_log: true
    test "should ignore the order when order_by or order is missing" do
      table_schema = %{
        "columns" => ["author", "create_ts", "data", "type"],
        "table_name" => "any_table",
        "limit" => 1000
      }

      allow(Prestige.new_session(any()), return: :do_not_care)
      allow(Prestige.query!(any(), any()), return: :do_not_care)
      allow(Prestige.Result.as_maps(any()), return: @expected_events)
      assert {:ok, @expected_events} == Select.select_table(table_schema)
    end

    @tag capture_log: true
    test "should return in ascending order when order is missing" do
      expected_events = [
        %{
          "author" => "Author-2020-01-21 23:25:52.522084Z",
          "create_ts" => 1_579_649_152,
          "data" => "Data-2020-01-21 23:25:52.522107Z",
          "type" => "Type-2020-01-21 23:25:52.522111Z"
        },
        %{
          "author" => "Author-2020-01-21 23:29:20.171519Z",
          "create_ts" => 1_579_649_360,
          "data" => "Data-2020-01-21 23:29:20.171538Z",
          "type" => "Type-2020-01-21 23:29:20.171543Z"
        }
      ]

      table_schema = %{
        "columns" => ["author", "create_ts", "data", "type"],
        "table_name" => "any_table",
        "order_by" => "create_ts",
        "limit" => 1000
      }

      allow(Prestige.new_session(any()), return: :do_not_care)
      allow(Prestige.query!(any(), any()), return: :do_not_care)
      allow(Prestige.Result.as_maps(any()), return: expected_events)
      assert {:ok, expected_events} == Select.select_table(table_schema)
    end

    @tag capture_log: true
    test "should return error when table name is missing" do
      expected_error = {:error, %RuntimeError{message: "Table name missing"}}

      table_schema = %{
        "columns" => ["author", "create_ts", "data", "type"],
        "order_by" => "create_ts",
        "order" => "DESC",
        "limit" => 1000
      }

      assert expected_error == Select.select_table(table_schema)
    end
  end
end
