defmodule Forklift.Tables.StatementBuilderTest do
  use ExUnit.Case
  use Placebo

  alias Forklift.Tables.StatementBuilder

  describe "build_table_create_statement/2" do
    @tag capture_log: true
    test "converts schema type value to proper presto type" do
      schema = [
        %{name: "first_name", type: "string"},
        %{name: "height", type: "long"},
        %{name: "weight", type: "float"},
        %{name: "identifier", type: "decimal"},
        %{name: "payload", type: "json"}
      ]

      expected_statement =
        ~s|CREATE TABLE IF NOT EXISTS table_name ("first_name" varchar, "height" bigint, "weight" double, "identifier" decimal, "payload" varchar)|

      assert {:ok, result} = StatementBuilder.build_table_create_statement("table_name", schema)
      assert result == expected_statement
    end

    @tag capture_log: true
    test "handles row" do
      schema = [
        %{
          name: "spouse",
          type: "map",
          subSchema: [
            %{name: "first_name", type: "string"},
            %{
              name: "next_of_kin",
              type: "map",
              subSchema: [
                %{name: "first_name", type: "string"},
                %{name: "date_of_birth", type: "date"}
              ]
            }
          ]
        }
      ]

      expected_statement =
        {:ok,
         ~s|CREATE TABLE IF NOT EXISTS table_name ("spouse" row("first_name" varchar, "next_of_kin" row("first_name" varchar, "date_of_birth" date)))|}

      assert StatementBuilder.build_table_create_statement("table_name", schema) == expected_statement
    end

    @tag capture_log: true
    test "handles array" do
      schema = [
        %{name: "friend_names", type: "list", itemType: "string"}
      ]

      expected_statement = {:ok, ~s|CREATE TABLE IF NOT EXISTS table_name ("friend_names" array(varchar))|}

      assert StatementBuilder.build_table_create_statement("table_name", schema) == expected_statement
    end

    @tag capture_log: true
    test "handles array of maps" do
      schema = [
        %{
          name: "friend_groups",
          type: "list",
          itemType: "map",
          subSchema: [
            %{name: "first_name", type: "string"},
            %{name: "last_name", type: "string"}
          ]
        }
      ]

      expected_statement =
        {:ok,
         ~s|CREATE TABLE IF NOT EXISTS table_name ("friend_groups" array(row("first_name" varchar, "last_name" varchar)))|}

      assert StatementBuilder.build_table_create_statement("table_name", schema) == expected_statement
    end
  end

  @tag capture_log: true
  test "returns error tuple with type message when field cannot be mapped" do
    schema = [
      %{name: "my_field", type: "unsupported"}
    ]

    assert {:error, message} = StatementBuilder.build_table_create_statement("table_name", schema)
    assert message == "unsupported Type is not supported"
  end

  test "returns error tuple when given invalid schema" do
    schema = [
      %{name: "my_field"}
    ]

    assert {:error, message} = StatementBuilder.build_table_create_statement("table_name", schema)
    assert message == "Unable to parse schema; %KeyError{key: :type, message: nil, term: %{name: \"my_field\"}}"
  end
end
