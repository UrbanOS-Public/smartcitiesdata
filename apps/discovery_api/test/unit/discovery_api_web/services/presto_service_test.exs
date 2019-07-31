defmodule DiscoveryApiWeb.Services.PrestoServiceTest do
  use ExUnit.Case
  use Placebo
  import Checkov

  alias DiscoveryApiWeb.Services.PrestoService

  test "preview should query presto for given table" do
    dataset = "things_in_the_fire"
    response_from_execute = %{something: "Unique", id: Faker.UUID.v4()}

    list_of_maps = [
      %{"id" => Faker.UUID.v4(), name: Faker.Lorem.characters(3..10)},
      %{"id" => Faker.UUID.v4(), name: Faker.Lorem.characters(3..10)},
      %{"id" => Faker.UUID.v4(), name: Faker.Lorem.characters(3..10)}
    ]

    expect(Prestige.execute("select * from #{dataset} limit 50", rows_as_maps: true),
      return: response_from_execute
    )

    expect(Prestige.prefetch(response_from_execute), return: list_of_maps)

    result = PrestoService.preview(dataset)
    assert list_of_maps == result
  end

  test "preview_columns should query presto for given columns" do
    dataset = "things_in_the_fire"
    response_from_execute = %{something: "Unique", id: Faker.UUID.v4()}

    list_of_columns = ["col_a", "col_b", "col_c"]

    unprocessed_columns = [["col_a", "varchar", "", ""], ["col_b", "varchar", "", ""], ["col_c", "integer", "", ""]]

    expect(Prestige.execute("show columns from #{dataset}"), return: response_from_execute)

    expect(Prestige.prefetch(response_from_execute), return: unprocessed_columns)

    result = PrestoService.preview_columns(dataset)
    assert list_of_columns == result
  end

  describe "get_affected_tables/1" do
    test "reflects when statement involves a select" do
      statement = """
        WITH public_one AS (select a from public__one), public_two AS (select b from public__two)
        SELECT * FROM public_one JOIN public_two ON public_one.a = public_two.b
      """

      public_one_dataset =
        DiscoveryApi.Test.Helper.sample_model(%{
          private: false,
          systemName: "public__one"
        })

      public_two_dataset =
        DiscoveryApi.Test.Helper.sample_model(%{
          private: false,
          systemName: "public__two"
        })

      query_plan = %{
        "inputTableColumnInfos" => [
          %{
            "table" => %{
              "catalog" => "hive",
              "schemaTable" => %{
                "schema" => "default",
                "table" => public_one_dataset.systemName
              }
            },
            "columnConstraints" => []
          },
          %{
            "table" => %{
              "catalog" => "hive",
              "schemaTable" => %{
                "schema" => "default",
                "table" => public_two_dataset.systemName
              }
            },
            "columnConstraints" => []
          }
        ]
      }

      explain_return = [
        %{
          "Query Plan" => Jason.encode!(query_plan)
        }
      ]

      allow(Prestige.execute(any(), any()), return: explain_return)

      expected_read_tables = [public_one_dataset.systemName, public_two_dataset.systemName]
      assert {^expected_read_tables, []} = PrestoService.get_affected_tables(statement)
    end

    test "reflects when statement has an insert in the query" do
      statement = """
        INSERT INTO public__one SELECT * FROM public__two
      """

      public_one_dataset =
        DiscoveryApi.Test.Helper.sample_model(%{
          private: false,
          systemName: "public__one"
        })

      public_two_dataset =
        DiscoveryApi.Test.Helper.sample_model(%{
          private: false,
          systemName: "public__two"
        })

      query_plan = %{
        "inputTableColumnInfos" => [
          %{
            "table" => %{
              "catalog" => "hive",
              "schemaTable" => %{
                "schema" => "default",
                "table" => "public__two"
              }
            },
            "columnConstraints" => []
          }
        ],
        "outputTable" => %{
          "catalog" => "hive",
          "schemaTable" => %{
            "schema" => "default",
            "table" => "public__one"
          }
        }
      }

      explain_return = [
        %{
          "Query Plan" => Jason.encode!(query_plan)
        }
      ]

      allow(Prestige.execute(any(), any()), return: explain_return)

      expected_read_tables = [public_two_dataset.systemName]
      expected_write_tables = [public_one_dataset.systemName]

      assert {^expected_read_tables, ^expected_write_tables} = PrestoService.get_affected_tables(statement)
    end

    test "reflects when statement is not in the hive.default catalog and schema" do
      statement = """
        SHOW TABLES
      """

      query_plan = %{
        "inputTableColumnInfos" => [
          %{
            "table" => %{
              "catalog" => "$info_schema@hive",
              "schemaTable" => %{
                "schema" => "information_schema",
                "table" => "tables"
              }
            },
            "columnConstraints" => []
          }
        ]
      }

      explain_return = [
        %{
          "Query Plan" => Jason.encode!(query_plan)
        }
      ]

      allow(Prestige.execute(any(), any()), return: explain_return)

      assert {[], []} = PrestoService.get_affected_tables(statement)
    end

    test "reflects when statement does not do IO operations" do
      statement = """
        DROP TABLE public__one
      """

      explain_return = [
        %{
          "Query Plan" => "DROP TABLE public__one"
        }
      ]

      allow(Prestige.execute(any(), any()), return: explain_return)

      assert {[], []} = PrestoService.get_affected_tables(statement)
    end

    test "reflects when statement does not read or write to anything at all" do
      statement = """
        EXPLAIN SELECT * FROM public__one
      """

      query_plan = %{
        "inputTableColumnInfos" => []
      }

      explain_return = [
        %{
          "Query Plan" => Jason.encode!(query_plan)
        }
      ]

      allow(Prestige.execute(any(), any()), return: explain_return)

      assert {[], []} = PrestoService.get_affected_tables(statement)
    end

    test "reflects when presto does not like the statement at all" do
      statement = """
        THIS WILL NOT WORK
      """

      allow(Prestige.execute(any(), any()), exec: fn _, _ -> raise Prestige.Error, message: "bad thing" end)

      assert {[], []} = PrestoService.get_affected_tables(statement)
    end
  end

  describe "supported statements" do
    data_test "statement starting with #{inspect(statement)}" do
      assert supported == PrestoService.supported?(statement)

      where([
        [:statement, :supported],
        ["\nWITH stuff\n SELECT lines from thingy ", true],
        ["\nMORE stuff\n SELECT lines from thingy ", false],
        ["  SELECT descending from explainer ", true],
        [" SELECT grantor, revoked from dogs; DROP TABLE cats ", true],
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
end
