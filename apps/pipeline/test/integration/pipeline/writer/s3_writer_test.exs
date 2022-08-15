defmodule Pipeline.Writer.S3WriterTest do
  use ExUnit.Case
  use Divo
  use Placebo

  alias Pipeline.Writer.S3Writer
  alias Pipeline.Writer.TableWriter
  alias Pipeline.Writer.S3Writer.Compaction
  alias Pipeline.Writer.TableWriter.Helper.PrestigeHelper
  alias SmartCity.TestDataGenerator, as: TDG
  alias Pipeline.TestHandler
  import SmartCity.TestHelper, only: [eventually: 1]

  @expected_table_values [
    %{
      "Column" => "two",
      "Comment" => "",
      "Extra" => "",
      "Type" => "row(three decimal(18,3))"
    },
    %{
      "Column" => "four",
      "Comment" => "",
      "Extra" => "",
      "Type" => "array(row(five decimal(18,3)))"
    },
    %{"Column" => "six", "Comment" => "", "Extra" => "", "Type" => "integer"}
  ]

  @expected_table_values_partitioned [
    %{
      "Column" => "two",
      "Comment" => "",
      "Extra" => "",
      "Type" => "row(three decimal(18,3))"
    },
    %{
      "Column" => "four",
      "Comment" => "",
      "Extra" => "",
      "Type" => "array(row(five decimal(18,3)))"
    },
    %{"Column" => "six", "Comment" => "", "Extra" => "partition key", "Type" => "integer"}
  ]

  @table_schema [
    %{name: "two", type: "map", subSchema: [%{name: "three", type: "decimal(18,3)"}]},
    %{
      name: "four",
      type: "list",
      itemType: "map",
      subSchema: [%{name: "five", type: "decimal(18,3)"}]
    },
    %{name: "six", type: "integer"}
  ]

  setup do
    session = PrestigeHelper.create_session()
    TestHandler.drop_all_tables()
    [session: session]
  end

  describe "init/1" do
    test "creates table with correct name and schema", %{session: session} do
      dataset =
        TDG.create_dataset(%{
          technical: %{systemName: "org_name__dataset_name", schema: @table_schema}
        })

      S3Writer.init(table: dataset.technical.systemName, schema: dataset.technical.schema)

      eventually(fn ->
        table = "describe hive.default.org_name__dataset_name__json"

        result =
          session
          |> Prestige.execute!(table)
          |> Prestige.Result.as_maps()

        assert result == @expected_table_values
      end)
    end

    test "creates table with correct partitions", %{session: session} do
      system_name = "org_name__partition_dataset"

      dataset =
        TDG.create_dataset(%{
          technical: %{systemName: system_name, schema: @table_schema}
        })

      init_result =
        S3Writer.init(table: dataset.technical.systemName, schema: dataset.technical.schema, partitions: ["six"])

      assert init_result == :ok

      eventually(fn ->
        table = "describe hive.default.#{system_name}"

        resulting_table =
          session
          |> Prestige.execute!(table)
          |> Prestige.Result.as_maps()

        assert resulting_table == @expected_table_values_partitioned
      end)
    end

    test "handles prestige errors for invalid table names" do
      schema = [
        %{name: "five", type: "list", itemType: "string"},
        %{name: "two", type: "map", subSchema: [%{name: "three", type: "decimal(18,3)"}]},
        %{name: "four", type: "list", itemType: "map", subSchema: [%{name: "five", type: "integer"}]}
      ]

      dataset = TDG.create_dataset(%{technical: %{systemName: "this.is.invalid", schema: schema}})

      assert {:error, _} = S3Writer.init(table: dataset.technical.systemName, schema: dataset.technical.schema)
    end

    test "escapes invalid column names", %{session: session} do
      expected = [%{"Column" => "on", "Comment" => "", "Extra" => "", "Type" => "boolean"}]
      schema = [%{name: "on", type: "boolean"}]
      dataset = TDG.create_dataset(%{technical: %{systemName: "foo", schema: schema}})
      S3Writer.init(table: dataset.technical.systemName, schema: dataset.technical.schema)

      eventually(fn ->
        table = "describe hive.default.foo__json"

        result =
          session
          |> Prestige.execute!(table)
          |> Prestige.Result.as_maps()

        assert result == expected
      end)
    end
  end

  describe "write/2" do
    test "inserts records", %{session: session} do
      schema = [%{name: "five", type: "string"}, %{name: "two", type: "integer"}]
      dataset = TDG.create_dataset(%{technical: %{systemName: "foo__bar", schema: schema}})

      S3Writer.init(table: dataset.technical.systemName, schema: schema)

      datum1 = TDG.create_data(%{dataset_id: dataset.id, payload: %{"five" => "hello", "two" => 42}})
      datum2 = TDG.create_data(%{dataset_id: dataset.id, payload: %{"five" => "goodbye", "two" => 9001}})

      S3Writer.write([datum1, datum2], table: dataset.technical.systemName, schema: schema, bucket: "trino-hive-storage")

      eventually(fn ->
        query = "select * from foo__bar__json"

        result =
          session
          |> Prestige.query!(query)
          |> Prestige.Result.as_maps()

        assert result == [%{"five" => "hello", "two" => 42}, %{"five" => "goodbye", "two" => 9001}]
      end)
    end

    test "inserts records, creating the table when it does not exist", %{session: session} do
      schema = [%{name: "five", type: "string"}, %{name: "two", type: "integer"}]
      dataset = TDG.create_dataset(%{technical: %{systemName: "Goo__Bar", schema: schema}})

      datum1 = TDG.create_data(%{dataset_id: dataset.id, payload: %{"five" => "hello", "two" => 42}})
      datum2 = TDG.create_data(%{dataset_id: dataset.id, payload: %{"five" => "goodbye", "two" => 9001}})

      S3Writer.write([datum1, datum2], table: dataset.technical.systemName, schema: schema, bucket: "trino-hive-storage")

      eventually(fn ->
        query = "select * from goo__bar__json"

        result =
          session
          |> Prestige.query!(query)
          |> Prestige.Result.as_maps()

        assert result == [%{"five" => "hello", "two" => 42}, %{"five" => "goodbye", "two" => 9001}]
      end)
    end

    test "returns an error if it cannot create the table" do
      schema = [%{name: "five", type: "string"}, %{name: "two", type: "integer"}]
      dataset = TDG.create_dataset(%{technical: %{systemName: "suprisingly__there", schema: schema}})

      datum1 = TDG.create_data(%{dataset_id: dataset.id, payload: %{"five" => "hello", "two" => 42}})
      datum2 = TDG.create_data(%{dataset_id: dataset.id, payload: %{"five" => "goodbye", "two" => 9001}})

      ExAws.S3.upload(["Blarg"], "trino-hive-storage", "hive-s3/suprisingly__there/blarg.gz")
      |> ExAws.request()

      assert {:error, _} =
               S3Writer.write([datum1, datum2],
                 table: dataset.technical.systemName,
                 schema: schema,
                 bucket: "trino-hive-storage"
               )
    end

    test "inserts heavily nested records", %{session: session} do
      schema = [
        %{name: "first_name", type: "string"},
        %{name: "age", type: "decimal"},
        %{name: "friend_names", type: "list", itemType: "string"},
        %{
          name: "friends",
          type: "list",
          itemType: "map",
          subSchema: [
            %{name: "first_name", type: "string"},
            %{name: "pet", type: "string"}
          ]
        },
        %{
          name: "spouse",
          type: "map",
          subSchema: [
            %{name: "first_name", type: "string"},
            %{name: "gender", type: "string"},
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

      payload = %{
        "first_name" => "Joe",
        "age" => 10,
        "friend_names" => ["bob", "sally"],
        "friends" => [
          %{"first_name" => "Bill", "pet" => "Bunco"},
          %{"first_name" => "Sally", "pet" => "Bosco"}
        ],
        "spouse" => %{
          "first_name" => "Susan",
          "gender" => "female",
          "next_of_kin" => %{
            "first_name" => "Joel",
            "date_of_birth" => "1941-07-12T00:00:00Z"
          }
        }
      }

      dataset = TDG.create_dataset(%{technical: %{systemName: "foo__baz", schema: schema}})
      S3Writer.init(table: dataset.technical.systemName, schema: schema)

      datum = TDG.create_data(dataset_id: dataset.id, payload: payload)

      expected = %{
        "age" => "10",
        "first_name" => "Joe",
        "friend_names" => ["bob", "sally"],
        "friends" => [%{"first_name" => "Bill", "pet" => "Bunco"}, %{"first_name" => "Sally", "pet" => "Bosco"}],
        "spouse" => %{
          "first_name" => "Susan",
          "gender" => "female",
          "next_of_kin" => %{"date_of_birth" => "1941-07-12", "first_name" => "Joel"}
        }
      }

      assert :ok =
               S3Writer.write([datum], table: dataset.technical.systemName, schema: schema, bucket: "trino-hive-storage")

      eventually(fn ->
        query = "select * from foo__baz__json"

        result =
          session
          |> Prestige.execute!(query)
          |> Prestige.Result.as_maps()

        assert result == [expected]
      end)
    end
  end

  describe "compact/1" do
    test "compacts a table without changing data", %{session: session} do
      sub = [%{name: "three", type: "boolean"}]
      schema = [%{name: "five", type: "list", itemType: "decimal"}, %{name: "two", type: "map", subSchema: sub}]
      dataset = TDG.create_dataset(%{technical: %{schema: schema, systemName: "a__b"}})

      S3Writer.init(table: dataset.technical.systemName, schema: schema)

      Enum.each(1..15, fn n ->
        payload = %{"five" => [n], "two" => %{"three" => false}}
        datum = TDG.create_data(%{dataset_id: dataset.id, payload: payload})
        S3Writer.write([datum], table: dataset.technical.systemName, schema: schema, bucket: "trino-hive-storage")
      end)

      Enum.each(1..5, fn n ->
        payload = %{"five" => [n], "two" => %{"three" => false}}
        datum = TDG.create_data(%{dataset_id: dataset.id, payload: payload})
        TableWriter.write([datum], table: dataset.technical.systemName, schema: schema)
      end)

      eventually(fn ->
        orc_query = "select count(1) from #{dataset.technical.systemName}"

        orc_query_result =
          session
          |> Prestige.query!(orc_query)

        assert orc_query_result.rows == [[5]]

        json_query = "select count(1) from #{dataset.technical.systemName}__json"

        json_query_result =
          session
          |> Prestige.query!(json_query)

        assert json_query_result.rows == [[15]]
      end)

      assert :ok == S3Writer.compact(table: dataset.technical.systemName)

      eventually(fn ->
        orc_query = "select count(1) from #{dataset.technical.systemName}"

        orc_query_result =
          session
          |> Prestige.query!(orc_query)

        assert orc_query_result.rows == [[20]]

        json_query = "select count(1) from #{dataset.technical.systemName}__json"

        json_query_result =
          session
          |> Prestige.query!(json_query)

        assert json_query_result.rows == [[0]]
      end)
    end

    test "skips compaction (and tells you that it skipped it) for empty json table", %{session: session} do
      sub = [%{name: "three", type: "boolean"}]
      schema = [%{name: "five", type: "list", itemType: "decimal"}, %{name: "two", type: "map", subSchema: sub}]
      dataset = TDG.create_dataset(%{technical: %{schema: schema, systemName: "d__e"}})

      S3Writer.init(table: dataset.technical.systemName, schema: schema)

      Enum.each(1..5, fn n ->
        payload = %{"five" => [n], "two" => %{"three" => false}}
        datum = TDG.create_data(%{dataset_id: dataset.id, payload: payload})
        TableWriter.write([datum], table: dataset.technical.systemName, schema: schema)
      end)

      eventually(fn ->
        orc_query = "select count(1) from #{dataset.technical.systemName}"

        orc_query_result =
          session
          |> Prestige.query!(orc_query)

        assert orc_query_result.rows == [[5]]

        json_query = "select count(1) from #{dataset.technical.systemName}__json"

        json_query_result =
          session
          |> Prestige.query!(json_query)

        assert json_query_result.rows == [[0]]
      end)

      assert :skipped == S3Writer.compact(table: dataset.technical.systemName)

      eventually(fn ->
        orc_query = "select count(1) from #{dataset.technical.systemName}"

        orc_query_result =
          session
          |> Prestige.query!(orc_query)

        assert orc_query_result.rows == [[5]]

        json_query = "select count(1) from #{dataset.technical.systemName}__json"

        json_query_result =
          session
          |> Prestige.query!(json_query)

        assert json_query_result.rows == [[0]]
      end)
    end

    test "skips compaction (and tells you that it skipped it) for missing json table" do
      dataset = TDG.create_dataset(%{technical: %{systemName: "f__g"}})

      assert :skipped == S3Writer.compact(table: dataset.technical.systemName)
    end

    test "fails without altering state if it was going to change data", %{session: session} do
      allow Compaction.measure(any(), any()), return: {6, 10}, meck_options: [:passthrough]

      schema = [%{name: "abc", type: "string"}]
      dataset = TDG.create_dataset(%{technical: %{schema: schema, systemName: "xyz"}})

      S3Writer.init(table: dataset.technical.systemName, schema: schema)

      Enum.each(1..15, fn n ->
        payload = %{"abc" => "#{n}"}
        datum = TDG.create_data(%{dataset_id: dataset.id, payload: payload})
        S3Writer.write([datum], table: "xyz", schema: schema, bucket: "trino-hive-storage")
      end)

      assert {:error, _} = S3Writer.compact(table: "xyz")

      eventually(fn ->
        query = "select count(1) from xyz__json"

        result =
          session
          |> Prestige.query!(query)

        assert result.rows == [[15]]
      end)
    end
  end

  test "should delete and rename the orc and json table when delete table is called", %{session: session} do
    dataset =
      TDG.create_dataset(%{
        technical: %{systemName: "some_system_name", schema: @table_schema}
      })

    [table: dataset.technical.systemName, schema: dataset.technical.schema]
    |> S3Writer.init()

    eventually(fn ->
      assert @expected_table_values ==
               "DESCRIBE #{dataset.technical.systemName}"
               |> execute_query(session)

      assert @expected_table_values ==
               "DESCRIBE #{dataset.technical.systemName}__json"
               |> execute_query(session)
    end)

    [dataset: dataset]
    |> S3Writer.delete()

    eventually(fn ->
      expected_table_name =
        "SHOW TABLES LIKE '%#{dataset.technical.systemName}%'"
        |> execute_query(session)
        |> Enum.find(fn tables ->
          tables["Table"]
          |> String.ends_with?(dataset.technical.systemName)
        end)
        |> verify_deleted_table_name(dataset.technical.systemName)

      assert @expected_table_values ==
               "DESCRIBE #{expected_table_name}"
               |> execute_query(session)

      assert @expected_table_values ==
               "DESCRIBE #{expected_table_name}__json"
               |> execute_query(session)
    end)
  end

  defp execute_query(query, session) do
    session
    |> Prestige.execute!(query)
    |> Prestige.Result.as_maps()
  end

  defp verify_deleted_table_name(table, table_name) do
    case String.starts_with?(table["Table"], "deleted") do
      true -> table["Table"]
      _ -> nil
    end
  end
end
