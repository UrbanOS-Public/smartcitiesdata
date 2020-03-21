defmodule DiscoveryApi.Services.PrestoServiceTest do
  use ExUnit.Case
  use Placebo
  import Checkov

  alias DiscoveryApi.Services.PrestoService

  setup do
    allow(Prestige.new_session(any()), return: :connection)
    :ok
  end

  test "preview should query presto for given table" do
    dataset = "things_in_the_fire"

    list_of_maps = [
      %{"id" => Faker.UUID.v4(), name: Faker.Lorem.characters(3..10)},
      %{"id" => Faker.UUID.v4(), name: Faker.Lorem.characters(3..10)},
      %{"id" => Faker.UUID.v4(), name: Faker.Lorem.characters(3..10)}
    ]

    allow(Prestige.query!(:connection, "select * from #{dataset} limit 50"), return: :result)
    expect(Prestige.Result.as_maps(:result), return: list_of_maps)

    result = PrestoService.preview(:connection, dataset)
    assert list_of_maps == result
  end

  test "preview_columns should query presto for given columns" do
    dataset = "things_in_the_fire"

    list_of_columns = ["col_a", "col_b", "col_c"]

    unprocessed_columns = %Prestige.Result{
      columns: :doesnt_matter,
      presto_headers: :doesnt_matter,
      rows: [["col_a", "varchar", "", ""], ["col_b", "varchar", "", ""], ["col_c", "integer", "", ""]]
    }

    allow(Prestige.query!(:connection, "show columns from #{dataset}"), return: unprocessed_columns)

    result = PrestoService.preview_columns(:connection, dataset)
    assert list_of_columns == result
  end

  describe "get_affected_tables/1" do
    setup do
      public_one_model =
        DiscoveryApi.Test.Helper.sample_model(%{
          private: false,
          systemName: "public__one"
        })

      public_two_model =
        DiscoveryApi.Test.Helper.sample_model(%{
          private: false,
          systemName: "public__two"
        })

      public_one_table = public_one_model.systemName
      public_two_table = public_two_model.systemName

      {:ok, %{public_one_table: public_one_table, public_two_table: public_two_table}}
    end

    test "reflects when statement involves a select", %{public_one_table: public_one_table, public_two_table: public_two_table} do
      statement = """
        WITH public_one AS (select a from public__one), public_two AS (select b from public__two)
        SELECT * FROM public_one JOIN public_two ON public_one.a = public_two.b
      """

      explain_return = make_explain_output(make_query_plan([%{name: public_one_table}, %{name: public_two_table}]))

      allow(Prestige.query!(any(), any()), return: :result)
      allow(Prestige.Result.as_maps(any()), return: explain_return)

      expected_read_tables = [public_one_table, public_two_table]
      assert {:ok, ^expected_read_tables} = PrestoService.get_affected_tables(any(), statement)
    end

    test "reflects when statement has an insert in the query", %{public_one_table: public_one_table, public_two_table: public_two_table} do
      statement = """
        INSERT INTO public__one SELECT * FROM public__two
      """

      explain_return = make_explain_output(make_query_plan([%{name: public_two_table}], %{name: public_one_table}))

      allow(Prestige.query!(any(), any()), return: :result)
      allow(Prestige.Result.as_maps(:result), return: explain_return)

      assert {:error, _} = PrestoService.get_affected_tables(any(), statement)
    end

    test "reflects when statement is not in the hive.default catalog and schema" do
      statement = """
        SHOW TABLES
      """

      explain_return = make_explain_output(make_query_plan([%{catalog: "$info_schema@hive", schema: "information_schema"}]))

      allow(Prestige.query!(any(), any()), return: :result)
      allow(Prestige.Result.as_maps(:result), return: explain_return)

      assert {:error, _} = PrestoService.get_affected_tables(any(), statement)
    end

    test "reflects when statement does not do IO operations" do
      statement = "DROP TABLE public__one"

      explain_return = make_explain_output(make_query_plan(statement))

      allow(Prestige.query!(any(), any()), return: :result)
      allow(Prestige.Result.as_maps(:result), return: explain_return)

      assert {:error, _} = PrestoService.get_affected_tables(any(), statement)
    end

    test "reflects when statement does not read or write to anything at all" do
      statement = """
        EXPLAIN SELECT * FROM public__one
      """

      explain_return = make_explain_output(make_query_plan([]))

      allow(Prestige.query!(any(), any()), return: :result)
      allow(Prestige.Result.as_maps(:result), return: explain_return)

      assert {:error, _} = PrestoService.get_affected_tables(any(), statement)
    end

    test "reflects when presto does not like the statement at all" do
      statement = """
        THIS WILL NOT WORK
      """

      allow(Prestige.query!(any(), any()), exec: fn _, _ -> raise Prestige.Error, message: "bad thing" end)

      assert {:error, _} = PrestoService.get_affected_tables(any(), statement)
    end
  end

  describe "is_select_statement?/1" do
    data_test "statement starting with #{inspect(statement)}" do
      assert is_it? == PrestoService.is_select_statement?(statement)

      where([
        [:statement, :is_it?],
        ["\nwith stuff\n SELECT lines from thingy ", true],
        ["\nMORE stuff\n SELECT lines from thingy ", false],
        ["  SELECT descending from explainer ", true],
        [" select grantor, revoked from dogs; DROP TABLE cats ", true],
        ["WITH grantor AS (select revoked, preparer, executed from cats) SELECT * from money ", true],
        ["ALTER SCHEMA explainer RENAME TO hove ", false],
        [" ALTER TABLE describer RENAME TO aloha ", false],
        ["  ANALYZE paul_tarps_off ", false],
        [" CALL stuff(1,2,3)", false],
        ["   COMMIT ", false],
        [" CREATE ROLE the_best", false],
        ["  CREATE SCHEMA hove", false],
        ["   CREATE TABLE revoked (name varchar, age int)", false],
        [" CREATE TABLE things AS SELECT * FROM dogs", false],
        ["  CREATE VIEW window AS SELECT * FROM walls", false],
        ["    DEALLOCATE PREPARE my_select1", false],
        ["   DELETE FROM thing", false],
        [" DESC stuff ", false],
        ["  DESCRIBE stuff ", false],
        ["   DESCRIBE INPUT my_select1 ", false],
        [" DESCRIBE OUTPUT my_select1 ", false],
        ["   DROP ROLE admin ", false],
        ["  DROP SCHEMA hive ", false],
        ["DROP TABLE stuff ", false],
        ["   DROP VIEW windows ", false],
        ["  EXECUTE my_select1 ", false],
        ["   EXPLAIN select * from dogs ", false],
        [" EXPLAIN ANALYZE select * from dogs    ", false],
        ["   GRANT ALL PRIVILEGES ON dogs TO USER cat ", false],
        ["    GRANT admin to USER cat  ", false],
        ["INSERT INTO jalson VALUES (1, 2, 3) ", false],
        ["   PREPARE my_select1 FROM select * from dogs ", false],
        ["    RESET SESSION hive.default ", false],
        ["  REVOKE ALL PRIVILEGES ON dogs FROM USER cat ", false],
        ["   REVOKE admin FROM USER cat  ", false],
        [" ROLLBACK  ", false],
        ["   SET ROLE ALL  ", false],
        ["    SET SESSION hive.default = false ", false],
        ["   SHOW CATALOGS  ", false],
        ["  SHOW COLUMNS FROM stuff  ", false],
        [" SHOW CREATE TABLE dogs  ", false],
        ["   SHOW CREATE VIEW windows  ", false],
        ["   SHOW FUNCTIONS  ", false],
        ["     SHOW GRANTS ON TABLE dogs  ", false],
        ["   SHOW ROLE GRANTS  ", false],
        ["     SHOW ROLES FROM hive.default   ", false],
        ["  SHOW SCHEMAS FROM hive  ", false],
        ["   SHOW SESSION  ", false],
        ["SHOW STATS FOR dog ", false],
        ["   SHOW TABLES  ", false],
        ["     START TRANSACTION  ", false],
        ["   USE hive.default    ", false],
        ["    VALUES 1, 2, 3    ", false]
      ])
    end
  end

  defp make_explain_output(query_plan) do
    [
      %{
        "Query Plan" => query_plan
      }
    ]
  end

  defp make_query_plan_table(table) do
    defaults = %{
      name: "wahtever",
      catalog: "hive",
      schema: "default"
    }

    defaulted = Map.merge(defaults, table)

    %{
      "catalog" => defaulted.catalog,
      "schemaTable" => %{
        "schema" => defaulted.schema,
        "table" => defaulted.name
      }
    }
  end

  defp make_query_plan(read_tables, write_table), do: Jason.encode!(do_make_query_plan(read_tables, write_table))
  defp make_query_plan(string_based_plan) when is_binary(string_based_plan), do: string_based_plan
  defp make_query_plan(read_tables), do: Jason.encode!(do_make_query_plan(read_tables))

  defp do_make_query_plan(read_tables, write_table) do
    query_plan = do_make_query_plan(read_tables)
    Map.put(query_plan, "outputTable", make_query_plan_table(write_table))
  end

  defp do_make_query_plan(read_tables) when is_list(read_tables) do
    table_infos =
      Enum.map(read_tables, fn table ->
        %{
          "table" => make_query_plan_table(table),
          "columnConstraints" => []
        }
      end)

    %{
      "inputTableColumnInfos" => table_infos
    }
  end
end
