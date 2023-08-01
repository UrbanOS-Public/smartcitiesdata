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

    schema = [
      %{name: "Thing1"},
      %{name: "Thing2"},
      %{name: "Thing3"}
    ]

    list_of_maps = [
      %{"id" => Faker.UUID.v4(), name: "thing1"},
      %{"id" => Faker.UUID.v4(), name: "thing2"},
      %{"id" => Faker.UUID.v4(), name: "thing3"}
    ]

    allow(Prestige.query!(:connection, "select thing1 as \"Thing1\", thing2 as \"Thing2\", thing3 as \"Thing3\" from #{dataset} limit 50"),
      return: :result
    )

    expect(Prestige.Result.as_maps(:result), return: list_of_maps)

    result = PrestoService.preview(:connection, dataset, schema)
    assert list_of_maps == result
  end

  test "preview should convert all hyphens to underscores to match table creation logic and sql constraints" do
    dataset = "some_test_dataset"

    schema = [
      %{name: "some_thing"},
      %{name: "other-thing"},
      %{name: "some-thing-else"}
    ]

    list_of_maps = [
      %{"id" => Faker.UUID.v4(), name: "some_thing"},
      %{"id" => Faker.UUID.v4(), name: "other-thing"},
      %{"id" => Faker.UUID.v4(), name: "some-thing-else"}
    ]

    allow(
      Prestige.query!(
        :connection,
        "select some_thing as \"some_thing\", other_thing as \"other-thing\", some_thing_else as \"some-thing-else\" from #{dataset} limit 50"
      ),
      return: :result
    )

    expect(Prestige.Result.as_maps(:result), return: list_of_maps)

    result = PrestoService.preview(:connection, dataset, schema)
    assert list_of_maps == result
  end

  test "preview should query presto for given table with nested data and map case based on schema" do
    dataset = "nested_dataset"

    schema = [
      %{
        name: "PARENT",
        subSchema: [
          %{
            name: "Children",
            subSchema: [
              %{
                name: "Age",
                subSchema: [],
                type: "integer"
              },
              %{
                name: "Name",
                subSchema: [],
                type: "string"
              }
            ],
            type: "list"
          },
          %{name: "ParentName", subSchema: [], type: "string"},
          %{name: "ParentType", subSchema: [], type: "string"}
        ],
        technical_id: "f51e937b-db8d-467d-b31b-5b9e2a7c3c07",
        type: "list"
      }
    ]

    list_of_maps = [
      %{
        "_extraction_start_time" => "202305011200",
        "PARENT" => [
          %{
            "children" => [%{"age" => 17, "name" => "Winfred"}, %{"age" => 25, "name" => "Tabitha"}],
            "parentname" => "Meredeth",
            "parenttype" => "Mother"
          },
          %{
            "children" => [%{"age" => 3, "name" => "Gretchen"}, %{"age" => 7, "name" => "Ferdinand"}],
            "parentname" => "Ricktavian",
            "parenttype" => "Father"
          }
        ]
      }
    ]

    expected = [
      %{
        "_extraction_start_time" => "202305011200",
        "PARENT" => [
          %{
            "Children" => [%{"Age" => 17, "Name" => "Winfred"}, %{"Age" => 25, "Name" => "Tabitha"}],
            "ParentName" => "Meredeth",
            "ParentType" => "Mother"
          },
          %{
            "Children" => [%{"Age" => 3, "Name" => "Gretchen"}, %{"Age" => 7, "Name" => "Ferdinand"}],
            "ParentName" => "Ricktavian",
            "ParentType" => "Father"
          }
        ]
      }
    ]

    allow(Prestige.query!(:connection, "select parent as \"PARENT\" from #{dataset} limit 50"),
      return: :result
    )

    expect(Prestige.Result.as_maps(:result), return: list_of_maps)

    result = PrestoService.preview(:connection, dataset, schema)
    assert result == expected
  end

  test "Complex scenario of Real Geo Json data with case sensitivity" do
    dataset = "nested_dataset"

    schema = real_geojson_data_schema()
    list_of_maps = real_geo_json_data()
    expected = real_geo_json_case_sensitive_data()

    allow(Prestige.query!(:connection, any()),
      return: :result
    )

    expect(Prestige.Result.as_maps(:result), return: list_of_maps)

    result = PrestoService.preview(:connection, dataset, schema)
    assert result == expected
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

      assert {:sql_error, _} = PrestoService.get_affected_tables(any(), statement)
    end
  end

  describe "map_prestige_results_to_schema" do
    test "returns list as normal if there are no subschemas" do
      schema = [
        %{
          name: "regular_field",
          subSchema: [],
          technical_id: "some-id"
        }
      ]

      list_of_maps = [
        %{
          "_extraction_start_time" => "202305011200",
          "regular_field" => "hello"
        }
      ]

      expected = [
        %{
          "_extraction_start_time" => "202305011200",
          "regular_field" => "hello"
        }
      ]

      actual = PrestoService.map_prestige_results_to_schema(list_of_maps, schema)

      assert actual == expected
    end

    test "returns single result mapped with schema" do
      schema = [
        %{
          name: "CAPS_FIELD",
          type: "list",
          itemType: "map",
          subSchema: [
            %{
              name: "SUB_CAPS_FIELD1",
              type: "string",
              subSchema: []
            },
            %{
              name: "SUB_CAPS_FIELD2",
              subSchema: [],
              type: "string"
            }
          ],
          technical_id: "some-id"
        }
      ]

      list_of_maps = [
        %{
          "_extraction_start_time" => "202305011200",
          "caps_field" => [
            %{"sub_caps_field1" => "hello", "sub_caps_field2" => "world"}
          ]
        }
      ]

      expected = [
        %{
          "_extraction_start_time" => "202305011200",
          "CAPS_FIELD" => [
            %{"SUB_CAPS_FIELD1" => "hello", "SUB_CAPS_FIELD2" => "world"}
          ]
        }
      ]

      actual = PrestoService.map_prestige_results_to_schema(list_of_maps, schema)

      assert actual == expected
    end

    test "returns list of results mapped with schema" do
      schema = [
        %{
          name: "CAPS_FIELD",
          subSchema: [
            %{
              name: "SUB_CAPS_FIELD1",
              subSchema: []
            },
            %{
              name: "SUB_CAPS_FIELD2",
              subSchema: []
            }
          ],
          technical_id: "some-id"
        }
      ]

      list_of_maps = [
        %{
          "_extraction_start_time" => "202305011200",
          "caps_field" => [
            %{"sub_caps_field1" => "hello", "sub_caps_field2" => "world"}
          ]
        },
        %{
          "_extraction_start_time" => "202305011200",
          "caps_field" => [
            %{"sub_caps_field1" => "second", "sub_caps_field2" => "field"}
          ]
        }
      ]

      expected = [
        %{
          "_extraction_start_time" => "202305011200",
          "CAPS_FIELD" => [
            %{"SUB_CAPS_FIELD1" => "hello", "SUB_CAPS_FIELD2" => "world"}
          ]
        },
        %{
          "_extraction_start_time" => "202305011200",
          "CAPS_FIELD" => [
            %{"SUB_CAPS_FIELD1" => "second", "SUB_CAPS_FIELD2" => "field"}
          ]
        }
      ]

      actual = PrestoService.map_prestige_results_to_schema(list_of_maps, schema)

      assert actual == expected
    end

    test "returns results if schema missing subSchema" do
      schema = [
        %{
          name: "regular_field",
          technical_id: "some-id"
        }
      ]

      list_of_maps = [
        %{
          "_extraction_start_time" => "202305011200",
          "regular_field" => "hello"
        },
        %{
          "_extraction_start_time" => "202305011200",
          "regular_field" => "world"
        }
      ]

      expected = [
        %{
          "_extraction_start_time" => "202305011200",
          "regular_field" => "hello"
        },
        %{
          "_extraction_start_time" => "202305011200",
          "regular_field" => "world"
        }
      ]

      actual = PrestoService.map_prestige_results_to_schema(list_of_maps, schema)

      assert actual == expected
    end

    test "returns as normal if data is missing meta fields" do
      schema = [
        %{
          name: "CAPS_FIELD",
          subSchema: [
            %{
              name: "SUB_CAPS_FIELD1",
              subSchema: []
            },
            %{
              name: "SUB_CAPS_FIELD2",
              subSchema: []
            }
          ],
          technical_id: "some-id"
        }
      ]

      list_of_maps = [
        %{
          "caps_field" => [
            %{"sub_caps_field1" => "hello", "sub_caps_field2" => "world"}
          ]
        },
        %{
          "caps_field" => [
            %{"sub_caps_field1" => "second", "sub_caps_field2" => "field"}
          ]
        }
      ]

      expected = [
        %{
          "CAPS_FIELD" => [
            %{"SUB_CAPS_FIELD1" => "hello", "SUB_CAPS_FIELD2" => "world"}
          ]
        },
        %{
          "CAPS_FIELD" => [
            %{"SUB_CAPS_FIELD1" => "second", "SUB_CAPS_FIELD2" => "field"}
          ]
        }
      ]

      actual = PrestoService.map_prestige_results_to_schema(list_of_maps, schema)

      assert actual == expected
    end

    test "returns correct case with map of a map" do
      schema = [
        %{
          name: "Parent",
          subSchema: [
            %{
              name: "Children",
              subSchema: [
                %{
                  name: "ChildName"
                }
              ]
            }
          ]
        }
      ]

      list_of_maps = [
        %{
          "parent" => %{
            "children" => [%{"childname" => "Timothy"}]
          }
        }
      ]

      expected = [
        %{
          "Parent" => %{
            "Children" => [%{"ChildName" => "Timothy"}]
          }
        }
      ]

      actual = PrestoService.map_prestige_results_to_schema(list_of_maps, schema)

      assert actual == expected
    end

    test "returns correct results with list of list of floats" do
      schema = [
        %{
          name: "Coordinates",
          subSchema: [
            %{
              name: "foo",
              subSchema: [
                %{
                  name: "bar",
                  subSchema: [
                    %{
                      name: "Baz"
                    }
                  ]
                }
              ]
            }
          ]
        }
      ]

      list_of_maps = [
        %{
          "coordinates" => [
            [
              [%{"baz" => "hi"}]
            ]
          ]
        }
      ]

      expected = [
        %{
          "Coordinates" => [
            [
              [%{"Baz" => "hi"}]
            ]
          ]
        }
      ]

      actual = PrestoService.map_prestige_results_to_schema(list_of_maps, schema)

      assert actual == expected
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

  describe "error sanitization" do
    data_test "statement starting with #{inspect(error)}" do
      assert sanitized == PrestoService.sanitize_error(error, "Test Error")

      where([
        [:error, :sanitized],
        ["line 1:41: Column 'missing_column' cannot be resolved", "Test Error: Column 'missing_column' cannot be resolved"],
        ["Column 'missing_column' cannot be resolved", "Test Error: Column 'missing_column' cannot be resolved"],
        [
          "Invalid X-Presto-Prepared-Statement header: line 1:77: mismatched input 'select'. expecting: ',', '.'",
          "Test Error: mismatched input 'select'. expecting: ',', '.'"
        ],
        ["line 1:15: Table hive.default.bob does not exist", "Bad Request"],
        [
          "Invalid X-Presto-Prepared-Statement header: line 1:78: mismatched input ';'. expecting: ',', '.'",
          "Test Error: mismatched input ';'. expecting: ',', '.'"
        ]
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

  defp real_geojson_data_schema() do
    [
      %{
        biased: "No",
        demographic: "None",
        description: "",
        ingestion_field_selector: "Feed_Info",
        ingestion_field_sync: true,
        masked: "N/A",
        name: "Feed_Info",
        pii: "None",
        sequence: 1339,
        subSchema: [
          %{
            biased: "No",
            demographic: "None",
            description: "",
            ingestion_field_selector: "PUBLISHER",
            ingestion_field_sync: true,
            masked: "N/A",
            name: "PUBLISHER",
            parent_id: "fed27917-725e-4717-a2e3-f28a9b0b14e2",
            pii: "None",
            sequence: 1340,
            subSchema: [],
            type: "string"
          },
          %{
            biased: "No",
            demographic: "None",
            description: "",
            format: "{ISO:Extended}",
            ingestion_field_selector: "Update_date",
            ingestion_field_sync: true,
            masked: "N/A",
            name: "Update_date",
            parent_id: "fed27917-725e-4717-a2e3-f28a9b0b14e2",
            pii: "None",
            sequence: 1341,
            subSchema: [],
            type: "timestamp"
          },
          %{
            biased: "No",
            demographic: "None",
            description: "",
            ingestion_field_selector: "contact_email",
            ingestion_field_sync: true,
            masked: "N/A",
            name: "contact_email",
            parent_id: "fed27917-725e-4717-a2e3-f28a9b0b14e2",
            pii: "None",
            sequence: 1342,
            subSchema: [],
            type: "string"
          },
          %{
            biased: "No",
            demographic: "None",
            description: "",
            ingestion_field_selector: "contact_name",
            ingestion_field_sync: true,
            masked: "N/A",
            name: "contact_name",
            parent_id: "fed27917-725e-4717-a2e3-f28a9b0b14e2",
            pii: "None",
            sequence: 1343,
            subSchema: [],
            type: "string"
          },
          %{
            biased: "No",
            demographic: "None",
            description: "",
            ingestion_field_selector: "data_sources",
            ingestion_field_sync: true,
            itemType: "map",
            masked: "N/A",
            name: "data_sources",
            parent_id: "fed27917-725e-4717-a2e3-f28a9b0b14e2",
            pii: "None",
            sequence: 1344,
            subSchema: [
              %{
                biased: "No",
                demographic: "None",
                description: "",
                ingestion_field_selector: "ORGANIZATION_NAME",
                ingestion_field_sync: true,
                masked: "N/A",
                name: "ORGANIZATION_NAME",
                parent_id: "8b8970f8-fc20-41fc-87be-34a7c1144887",
                pii: "None",
                sequence: 1345,
                subSchema: [],
                type: "string"
              },
              %{
                biased: "No",
                demographic: "None",
                description: "",
                ingestion_field_selector: "contact_email",
                ingestion_field_sync: true,
                masked: "N/A",
                name: "contact_email",
                parent_id: "8b8970f8-fc20-41fc-87be-34a7c1144887",
                pii: "None",
                sequence: 1346,
                subSchema: [],
                type: "string"
              },
              %{
                biased: "No",
                demographic: "None",
                description: "",
                ingestion_field_selector: "contact_name",
                ingestion_field_sync: true,
                masked: "N/A",
                name: "contact_name",
                parent_id: "8b8970f8-fc20-41fc-87be-34a7c1144887",
                pii: "None",
                sequence: 1347,
                subSchema: [],
                type: "string"
              },
              %{
                biased: "No",
                demographic: "None",
                description: "",
                ingestion_field_selector: "data_source_id",
                ingestion_field_sync: true,
                masked: "N/A",
                name: "data_source_id",
                parent_id: "8b8970f8-fc20-41fc-87be-34a7c1144887",
                pii: "None",
                sequence: 1348,
                subSchema: [],
                type: "string"
              },
              %{
                biased: "No",
                demographic: "None",
                description: "",
                format: "{ISO:Extended}",
                ingestion_field_selector: "update_date",
                ingestion_field_sync: true,
                masked: "N/A",
                name: "update_date",
                parent_id: "8b8970f8-fc20-41fc-87be-34a7c1144887",
                pii: "None",
                sequence: 1349,
                subSchema: [],
                type: "timestamp"
              },
              %{
                biased: "No",
                demographic: "None",
                description: "",
                ingestion_field_selector: "update_frequency",
                ingestion_field_sync: true,
                masked: "N/A",
                name: "update_frequency",
                parent_id: "8b8970f8-fc20-41fc-87be-34a7c1144887",
                pii: "None",
                sequence: 1350,
                subSchema: [],
                type: "integer"
              }
            ],
            type: "list"
          },
          %{
            biased: "No",
            demographic: "None",
            description: "",
            ingestion_field_selector: "license",
            ingestion_field_sync: true,
            masked: "N/A",
            name: "license",
            parent_id: "fed27917-725e-4717-a2e3-f28a9b0b14e2",
            pii: "None",
            sequence: 1351,
            subSchema: [],
            type: "string"
          },
          %{
            biased: "No",
            demographic: "None",
            description: "",
            ingestion_field_selector: "update_frequency",
            ingestion_field_sync: true,
            masked: "N/A",
            name: "update_frequency",
            parent_id: "fed27917-725e-4717-a2e3-f28a9b0b14e2",
            pii: "None",
            sequence: 1352,
            subSchema: [],
            type: "integer"
          },
          %{
            biased: "No",
            demographic: "None",
            description: "",
            ingestion_field_selector: "version",
            ingestion_field_sync: true,
            masked: "N/A",
            name: "version",
            parent_id: "fed27917-725e-4717-a2e3-f28a9b0b14e2",
            pii: "None",
            sequence: 1353,
            subSchema: [],
            type: "string"
          }
        ],
        technical_id: "3de24977-9690-4d52-b416-eb557cd95d62",
        type: "map"
      },
      %{
        biased: "No",
        demographic: "None",
        description: "",
        ingestion_field_selector: "features",
        ingestion_field_sync: true,
        itemType: "map",
        masked: "N/A",
        name: "features",
        pii: "None",
        sequence: 1354,
        subSchema: [
          %{
            biased: "No",
            demographic: "None",
            description: "",
            ingestion_field_selector: "geometry",
            ingestion_field_sync: true,
            masked: "N/A",
            name: "geometry",
            parent_id: "616fde74-ffcd-4a10-b14f-c24c039df505",
            pii: "None",
            sequence: 1355,
            subSchema: [
              %{
                biased: "No",
                demographic: "None",
                description: "",
                ingestion_field_selector: "Coordinates",
                ingestion_field_sync: true,
                itemType: "list",
                masked: "N/A",
                name: "Coordinates",
                parent_id: "ff027130-e509-48c8-a0d6-66811faca516",
                pii: "None",
                sequence: 1356,
                subSchema: [
                  %{
                    biased: "No",
                    demographic: "None",
                    description: "",
                    ingestion_field_selector: "child_of_list",
                    ingestion_field_sync: true,
                    itemType: "float",
                    masked: "N/A",
                    name: "child_of_list",
                    parent_id: "11c751c1-6dc1-4cdd-852c-713ad4c94d5f",
                    pii: "None",
                    sequence: 1357,
                    subSchema: [],
                    type: "list"
                  }
                ],
                type: "list"
              },
              %{
                biased: "No",
                demographic: "None",
                description: "",
                ingestion_field_selector: "type",
                ingestion_field_sync: true,
                masked: "N/A",
                name: "type",
                parent_id: "ff027130-e509-48c8-a0d6-66811faca516",
                pii: "None",
                sequence: 1358,
                subSchema: [],
                type: "string"
              }
            ],
            type: "map"
          },
          %{
            biased: "No",
            demographic: "None",
            description: "",
            ingestion_field_selector: "id",
            ingestion_field_sync: true,
            masked: "N/A",
            name: "id",
            parent_id: "616fde74-ffcd-4a10-b14f-c24c039df505",
            pii: "None",
            sequence: 1359,
            subSchema: [],
            type: "string"
          },
          %{
            biased: "No",
            demographic: "None",
            description: "",
            ingestion_field_selector: "properties",
            ingestion_field_sync: true,
            masked: "N/A",
            name: "properties",
            parent_id: "616fde74-ffcd-4a10-b14f-c24c039df505",
            pii: "None",
            sequence: 1360,
            subSchema: [
              %{
                biased: "No",
                demographic: "None",
                description: "",
                ingestion_field_selector: "beginning_cross_street",
                ingestion_field_sync: true,
                masked: "N/A",
                name: "beginning_cross_street",
                parent_id: "c36ae69d-f343-4004-badc-a210eb0134e9",
                pii: "None",
                sequence: 1361,
                subSchema: [],
                type: "string"
              },
              %{
                biased: "No",
                demographic: "None",
                description: "",
                ingestion_field_selector: "beginning_milepost",
                ingestion_field_sync: true,
                masked: "N/A",
                name: "beginning_milepost",
                parent_id: "c36ae69d-f343-4004-badc-a210eb0134e9",
                pii: "None",
                sequence: 1362,
                subSchema: [],
                type: "float"
              },
              %{
                biased: "No",
                demographic: "None",
                description: "",
                ingestion_field_selector: "core_details",
                ingestion_field_sync: true,
                masked: "N/A",
                name: "core_details",
                parent_id: "c36ae69d-f343-4004-badc-a210eb0134e9",
                pii: "None",
                sequence: 1363,
                subSchema: [
                  %{
                    biased: "No",
                    demographic: "None",
                    description: "",
                    ingestion_field_selector: "Data_Source_Id",
                    ingestion_field_sync: true,
                    masked: "N/A",
                    name: "Data_Source_Id",
                    parent_id: "3fd67440-28db-4a85-8fe4-0b0604722091",
                    pii: "None",
                    sequence: 1364,
                    subSchema: [],
                    type: "string"
                  },
                  %{
                    biased: "No",
                    demographic: "None",
                    description: "",
                    ingestion_field_selector: "Road_Names",
                    ingestion_field_sync: true,
                    itemType: "string",
                    masked: "N/A",
                    name: "Road_Names",
                    parent_id: "3fd67440-28db-4a85-8fe4-0b0604722091",
                    pii: "None",
                    sequence: 1365,
                    subSchema: [],
                    type: "list"
                  },
                  %{
                    biased: "No",
                    demographic: "None",
                    description: "",
                    format: "{ISO:Extended}",
                    ingestion_field_selector: "creation_date",
                    ingestion_field_sync: true,
                    masked: "N/A",
                    name: "creation_date",
                    parent_id: "3fd67440-28db-4a85-8fe4-0b0604722091",
                    pii: "None",
                    sequence: 1366,
                    subSchema: [],
                    type: "timestamp"
                  },
                  %{
                    biased: "No",
                    demographic: "None",
                    description: "",
                    ingestion_field_selector: "description",
                    ingestion_field_sync: true,
                    masked: "N/A",
                    name: "description",
                    parent_id: "3fd67440-28db-4a85-8fe4-0b0604722091",
                    pii: "None",
                    sequence: 1367,
                    subSchema: [],
                    type: "string"
                  },
                  %{
                    biased: "No",
                    demographic: "None",
                    description: "",
                    ingestion_field_selector: "direction",
                    ingestion_field_sync: true,
                    masked: "N/A",
                    name: "direction",
                    parent_id: "3fd67440-28db-4a85-8fe4-0b0604722091",
                    pii: "None",
                    sequence: 1368,
                    subSchema: [],
                    type: "string"
                  },
                  %{
                    biased: "No",
                    demographic: "None",
                    description: "",
                    ingestion_field_selector: "event_type",
                    ingestion_field_sync: true,
                    masked: "N/A",
                    name: "event_type",
                    parent_id: "3fd67440-28db-4a85-8fe4-0b0604722091",
                    pii: "None",
                    sequence: 1369,
                    subSchema: [],
                    type: "string"
                  },
                  %{
                    biased: "No",
                    demographic: "None",
                    description: "",
                    ingestion_field_selector: "name",
                    ingestion_field_sync: true,
                    masked: "N/A",
                    name: "name",
                    parent_id: "3fd67440-28db-4a85-8fe4-0b0604722091",
                    pii: "None",
                    sequence: 1370,
                    subSchema: [],
                    type: "string"
                  },
                  %{
                    biased: "No",
                    demographic: "None",
                    description: "",
                    ingestion_field_selector: "related_road_events",
                    ingestion_field_sync: true,
                    itemType: "map",
                    masked: "N/A",
                    name: "related_road_events",
                    parent_id: "3fd67440-28db-4a85-8fe4-0b0604722091",
                    pii: "None",
                    sequence: 1371,
                    subSchema: [
                      %{
                        biased: "No",
                        demographic: "None",
                        description: "",
                        ingestion_field_selector: "ID",
                        ingestion_field_sync: true,
                        masked: "N/A",
                        name: "ID",
                        parent_id: "1b9566c4-2180-45c0-9534-848a8224beaf",
                        pii: "None",
                        sequence: 1372,
                        subSchema: [],
                        type: "string"
                      },
                      %{
                        biased: "No",
                        demographic: "None",
                        description: "",
                        ingestion_field_selector: "type",
                        ingestion_field_sync: true,
                        masked: "N/A",
                        name: "type",
                        parent_id: "1b9566c4-2180-45c0-9534-848a8224beaf",
                        pii: "None",
                        sequence: 1373,
                        subSchema: [],
                        type: "string"
                      }
                    ],
                    type: "list"
                  },
                  %{
                    biased: "No",
                    demographic: "None",
                    description: "",
                    format: "{ISO:Extended}",
                    ingestion_field_selector: "update_date",
                    ingestion_field_sync: true,
                    masked: "N/A",
                    name: "update_date",
                    parent_id: "3fd67440-28db-4a85-8fe4-0b0604722091",
                    pii: "None",
                    sequence: 1374,
                    subSchema: [],
                    type: "timestamp"
                  }
                ],
                type: "map"
              },
              %{
                biased: "No",
                demographic: "None",
                description: "",
                format: "{ISO:Extended}",
                ingestion_field_selector: "end_date",
                ingestion_field_sync: true,
                masked: "N/A",
                name: "end_date",
                parent_id: "c36ae69d-f343-4004-badc-a210eb0134e9",
                pii: "None",
                sequence: 1375,
                subSchema: [],
                type: "timestamp"
              },
              %{
                biased: "No",
                demographic: "None",
                description: "",
                ingestion_field_selector: "ending_cross_street",
                ingestion_field_sync: true,
                masked: "N/A",
                name: "ending_cross_street",
                parent_id: "c36ae69d-f343-4004-badc-a210eb0134e9",
                pii: "None",
                sequence: 1376,
                subSchema: [],
                type: "string"
              },
              %{
                biased: "No",
                demographic: "None",
                description: "",
                ingestion_field_selector: "ending_milepost",
                ingestion_field_sync: true,
                masked: "N/A",
                name: "ending_milepost",
                parent_id: "c36ae69d-f343-4004-badc-a210eb0134e9",
                pii: "None",
                sequence: 1377,
                subSchema: [],
                type: "float"
              },
              %{
                biased: "No",
                demographic: "None",
                description: "",
                ingestion_field_selector: "is_end_date_verified",
                ingestion_field_sync: true,
                masked: "N/A",
                name: "is_end_date_verified",
                parent_id: "c36ae69d-f343-4004-badc-a210eb0134e9",
                pii: "None",
                sequence: 1378,
                subSchema: [],
                type: "boolean"
              },
              %{
                biased: "No",
                demographic: "None",
                description: "",
                ingestion_field_selector: "is_end_position_verified",
                ingestion_field_sync: true,
                masked: "N/A",
                name: "is_end_position_verified",
                parent_id: "c36ae69d-f343-4004-badc-a210eb0134e9",
                pii: "None",
                sequence: 1379,
                subSchema: [],
                type: "boolean"
              },
              %{
                biased: "No",
                demographic: "None",
                description: "",
                ingestion_field_selector: "is_start_date_verified",
                ingestion_field_sync: true,
                masked: "N/A",
                name: "is_start_date_verified",
                parent_id: "c36ae69d-f343-4004-badc-a210eb0134e9",
                pii: "None",
                sequence: 1380,
                subSchema: [],
                type: "boolean"
              },
              %{
                biased: "No",
                demographic: "None",
                description: "",
                ingestion_field_selector: "is_start_position_verified",
                ingestion_field_sync: true,
                masked: "N/A",
                name: "is_start_position_verified",
                parent_id: "c36ae69d-f343-4004-badc-a210eb0134e9",
                pii: "None",
                sequence: 1381,
                subSchema: [],
                type: "boolean"
              },
              %{
                biased: "No",
                demographic: "None",
                description: "",
                ingestion_field_selector: "lanes",
                ingestion_field_sync: true,
                itemType: "map",
                masked: "N/A",
                name: "lanes",
                parent_id: "c36ae69d-f343-4004-badc-a210eb0134e9",
                pii: "None",
                sequence: 1382,
                subSchema: [
                  %{
                    biased: "No",
                    demographic: "None",
                    description: "",
                    ingestion_field_selector: "order",
                    ingestion_field_sync: true,
                    masked: "N/A",
                    name: "order",
                    parent_id: "7dce7a61-918d-4634-90ba-96a9913f7125",
                    pii: "None",
                    sequence: 1383,
                    subSchema: [],
                    type: "integer"
                  },
                  %{
                    biased: "No",
                    demographic: "None",
                    description: "",
                    ingestion_field_selector: "restrictions",
                    ingestion_field_sync: true,
                    itemType: "map",
                    masked: "N/A",
                    name: "restrictions",
                    parent_id: "7dce7a61-918d-4634-90ba-96a9913f7125",
                    pii: "None",
                    sequence: 1384,
                    subSchema: [
                      %{
                        biased: "No",
                        demographic: "None",
                        description: "",
                        ingestion_field_selector: "UNIT",
                        ingestion_field_sync: true,
                        masked: "N/A",
                        name: "UNIT",
                        parent_id: "8afbfb5f-6925-44bd-928b-e308101f999e",
                        pii: "None",
                        sequence: 1385,
                        subSchema: [],
                        type: "string"
                      },
                      %{
                        biased: "No",
                        demographic: "None",
                        description: "",
                        ingestion_field_selector: "type",
                        ingestion_field_sync: true,
                        masked: "N/A",
                        name: "type",
                        parent_id: "8afbfb5f-6925-44bd-928b-e308101f999e",
                        pii: "None",
                        sequence: 1386,
                        subSchema: [],
                        type: "string"
                      },
                      %{
                        biased: "No",
                        demographic: "None",
                        description: "",
                        ingestion_field_selector: "value",
                        ingestion_field_sync: true,
                        masked: "N/A",
                        name: "value",
                        parent_id: "8afbfb5f-6925-44bd-928b-e308101f999e",
                        pii: "None",
                        sequence: 1387,
                        subSchema: [],
                        type: "integer"
                      }
                    ],
                    type: "list"
                  },
                  %{
                    biased: "No",
                    demographic: "None",
                    description: "",
                    ingestion_field_selector: "status",
                    ingestion_field_sync: true,
                    masked: "N/A",
                    name: "status",
                    parent_id: "7dce7a61-918d-4634-90ba-96a9913f7125",
                    pii: "None",
                    sequence: 1388,
                    subSchema: [],
                    type: "string"
                  },
                  %{
                    biased: "No",
                    demographic: "None",
                    description: "",
                    ingestion_field_selector: "type",
                    ingestion_field_sync: true,
                    masked: "N/A",
                    name: "type",
                    parent_id: "7dce7a61-918d-4634-90ba-96a9913f7125",
                    pii: "None",
                    sequence: 1389,
                    subSchema: [],
                    type: "string"
                  }
                ],
                type: "list"
              },
              %{
                biased: "No",
                demographic: "None",
                description: "",
                ingestion_field_selector: "location_method",
                ingestion_field_sync: true,
                masked: "N/A",
                name: "location_method",
                parent_id: "c36ae69d-f343-4004-badc-a210eb0134e9",
                pii: "None",
                sequence: 1390,
                subSchema: [],
                type: "string"
              },
              %{
                biased: "No",
                demographic: "None",
                description: "",
                ingestion_field_selector: "reduced_speed_limit_kph",
                ingestion_field_sync: true,
                masked: "N/A",
                name: "reduced_speed_limit_kph",
                parent_id: "c36ae69d-f343-4004-badc-a210eb0134e9",
                pii: "None",
                sequence: 1391,
                subSchema: [],
                type: "float"
              },
              %{
                biased: "No",
                demographic: "None",
                description: "",
                format: "{ISO:Extended}",
                ingestion_field_selector: "start_date",
                ingestion_field_sync: true,
                masked: "N/A",
                name: "start_date",
                parent_id: "c36ae69d-f343-4004-badc-a210eb0134e9",
                pii: "None",
                sequence: 1392,
                subSchema: [],
                type: "timestamp"
              },
              %{
                biased: "No",
                demographic: "None",
                description: "",
                ingestion_field_selector: "types_of_work",
                ingestion_field_sync: true,
                itemType: "map",
                masked: "N/A",
                name: "types_of_work",
                parent_id: "c36ae69d-f343-4004-badc-a210eb0134e9",
                pii: "None",
                sequence: 1393,
                subSchema: [
                  %{
                    biased: "No",
                    demographic: "None",
                    description: "",
                    ingestion_field_selector: "is_architectural_change",
                    ingestion_field_sync: true,
                    masked: "N/A",
                    name: "is_architectural_change",
                    parent_id: "a0ca2773-f48e-4e3b-aba6-bb2481cc484d",
                    pii: "None",
                    sequence: 1394,
                    subSchema: [],
                    type: "boolean"
                  },
                  %{
                    biased: "No",
                    demographic: "None",
                    description: "",
                    ingestion_field_selector: "type_name",
                    ingestion_field_sync: true,
                    masked: "N/A",
                    name: "type_name",
                    parent_id: "a0ca2773-f48e-4e3b-aba6-bb2481cc484d",
                    pii: "None",
                    sequence: 1395,
                    subSchema: [],
                    type: "string"
                  }
                ],
                type: "list"
              },
              %{
                biased: "No",
                demographic: "None",
                description: "",
                ingestion_field_selector: "vehicle_impact",
                ingestion_field_sync: true,
                masked: "N/A",
                name: "vehicle_impact",
                parent_id: "c36ae69d-f343-4004-badc-a210eb0134e9",
                pii: "None",
                sequence: 1396,
                subSchema: [],
                type: "string"
              },
              %{
                biased: "No",
                demographic: "None",
                description: "",
                ingestion_field_selector: "work_zone_type",
                ingestion_field_sync: true,
                masked: "N/A",
                name: "work_zone_type",
                parent_id: "c36ae69d-f343-4004-badc-a210eb0134e9",
                pii: "None",
                sequence: 1397,
                subSchema: [],
                type: "string"
              },
              %{
                biased: "No",
                demographic: "None",
                description: "",
                ingestion_field_selector: "worker_presence",
                ingestion_field_sync: true,
                masked: "N/A",
                name: "worker_presence",
                parent_id: "c36ae69d-f343-4004-badc-a210eb0134e9",
                pii: "None",
                sequence: 1398,
                subSchema: [
                  %{
                    biased: "No",
                    demographic: "None",
                    description: "",
                    ingestion_field_selector: "are_workers_present",
                    ingestion_field_sync: true,
                    masked: "N/A",
                    name: "are_workers_present",
                    parent_id: "77f22bf5-23d7-4c32-add3-ca4b81555438",
                    pii: "None",
                    sequence: 1399,
                    subSchema: [],
                    type: "boolean"
                  }
                ],
                type: "map"
              }
            ],
            type: "map"
          },
          %{
            biased: "No",
            demographic: "None",
            description: "",
            ingestion_field_selector: "type",
            ingestion_field_sync: true,
            masked: "N/A",
            name: "type",
            parent_id: "616fde74-ffcd-4a10-b14f-c24c039df505",
            pii: "None",
            sequence: 1400,
            subSchema: [],
            type: "string"
          }
        ],
        technical_id: "3de24977-9690-4d52-b416-eb557cd95d62",
        type: "list"
      },
      %{
        biased: "No",
        demographic: "None",
        description: "",
        ingestion_field_selector: "type",
        ingestion_field_sync: true,
        masked: "N/A",
        name: "type",
        pii: "None",
        sequence: 1401,
        subSchema: [],
        technical_id: "3de24977-9690-4d52-b416-eb557cd95d62",
        type: "string"
      }
    ]
  end

  defp real_geo_json_data() do
    [
      %{
        "feed_Info" => %{
          "update_date" => "2020-06-18T15:00:00Z",
          "publisher" => "Tester",
          "contact_name" => "Frederick Francis Feedmanager",
          "contact_email" => "fred.feedmanager@foo.com",
          "update_frequency" => 60,
          "version" => "4.2",
          "license" => "https://creativecommons.org/publicdomain/zero/1.0/",
          "data_sources" => [
            %{
              "data_source_id" => "1",
              "organization_name" => "Test City 1",
              "contact_name" => "Solomn Soliel Sourcefeed",
              "contact_email" => "solomon.sourcefeed@testcity1.gov",
              "update_frequency" => 300,
              "update_date" => "2020-06-18T14:37:31Z"
            }
          ]
        },
        "type" => "FeatureCollection",
        "features" => [
          %{
            "id" => "af2e3f51-611f-4ce0-9282-2f28ca68e62f",
            "type" => "Feature",
            "properties" => %{
              "core_details" => %{
                "name" => "WDM-58493-NB",
                "data_source_id" => "1",
                "event_type" => "work-zone",
                "road_names" => [
                  "I-80",
                  "I-35"
                ],
                "related_road_events" => [
                  %{
                    "id" => "6f57aded-7291-462e-9892-607b2b7d116c",
                    "type" => "first-in-sequence"
                  },
                  %{
                    "id" => "e6c2abad-04e2-41fd-bd66-4cc41e4bb6e7",
                    "type" => "next-in-sequence"
                  }
                ],
                "direction" => "northbound",
                "description" => "Single direction work zone without lane-level information.",
                "creation_date" => "2009-12-31T18:01:01Z",
                "update_date" => "2009-12-31T18:01:01Z"
              },
              "beginning_milepost" => 125.2,
              "beginning_cross_street" => "US 6, Hickman Road",
              "ending_milepost" => 126.3,
              "is_start_position_verified" => false,
              "is_end_position_verified" => false,
              "start_date" => "2010-01-01T01:00:00Z",
              "end_date" => "2010-01-02T01:00:00Z",
              "ending_cross_street" => "Douglas Ave",
              "location_method" => "channel-device-method",
              "is_start_date_verified" => false,
              "is_end_date_verified" => false,
              "vehicle_impact" => "some-lanes-closed",
              "reduced_speed_limit_kph" => 88.514,
              "types_of_work" => [
                %{
                  "is_architectural_change" => true,
                  "type_name" => "surface-work"
                }
              ],
              "worker_presence" => %{
                "are_workers_present" => false
              },
              "work_zone_type" => "static",
              "lanes" => [
                %{
                  "order" => 1,
                  "restrictions" => [
                    %{
                      "type" => "reduced-width",
                      "unit" => "feet",
                      "value" => 10
                    }
                  ],
                  "status" => "open",
                  "type" => "general"
                },
                %{
                  "order" => 2,
                  "status" => "closed",
                  "type" => "general"
                }
              ]
            },
            "geometry" => %{
              "type" => "LineString",
              "coordinates" => [
                [
                  -93.776684050999961,
                  41.617961698000045
                ],
                [
                  -93.776682957,
                  41.618244962000063
                ],
                [
                  -93.776677372999984,
                  41.619603362000078
                ],
                [
                  -93.776674365999952,
                  41.620322783000063
                ],
                [
                  -93.776671741999962,
                  41.620950321000066
                ],
                [
                  -93.776688974999956,
                  41.622297226000057
                ]
              ]
            }
          }
        ]
      }
    ]
  end

  defp real_geo_json_case_sensitive_data() do
    [
      %{
        "Feed_Info" => %{
          "Update_date" => "2020-06-18T15:00:00Z",
          # Map of Map of Primitive
          "PUBLISHER" => "Tester",
          "contact_name" => "Frederick Francis Feedmanager",
          "contact_email" => "fred.feedmanager@foo.com",
          "update_frequency" => 60,
          "version" => "4.2",
          "license" => "https://creativecommons.org/publicdomain/zero/1.0/",
          "data_sources" => [
            %{
              "data_source_id" => "1",
              # Map of Map of List of Maps of Primitives
              "ORGANIZATION_NAME" => "Test City 1",
              "contact_name" => "Solomn Soliel Sourcefeed",
              "contact_email" => "solomon.sourcefeed@testcity1.gov",
              "update_frequency" => 300,
              "update_date" => "2020-06-18T14:37:31Z"
            }
          ]
        },
        "type" => "FeatureCollection",
        "features" => [
          %{
            "id" => "af2e3f51-611f-4ce0-9282-2f28ca68e62f",
            "type" => "Feature",
            "properties" => %{
              "core_details" => %{
                "name" => "WDM-58493-NB",
                # Map of List of Maps of Map of Map of Primitive
                "Data_Source_Id" => "1",
                "event_type" => "work-zone",
                # Map of List of Maps of Map of Map of List of Primitive
                "Road_Names" => [
                  "I-80",
                  "I-35"
                ],
                # Map of List of Maps of Map of Map of List of Map of Primitive
                "related_road_events" => [
                  %{
                    "ID" => "6f57aded-7291-462e-9892-607b2b7d116c",
                    "type" => "first-in-sequence"
                  },
                  %{
                    "ID" => "e6c2abad-04e2-41fd-bd66-4cc41e4bb6e7",
                    "type" => "next-in-sequence"
                  }
                ],
                "direction" => "northbound",
                "description" => "Single direction work zone without lane-level information.",
                "creation_date" => "2009-12-31T18:01:01Z",
                "update_date" => "2009-12-31T18:01:01Z"
              },
              "beginning_milepost" => 125.2,
              "beginning_cross_street" => "US 6, Hickman Road",
              "ending_milepost" => 126.3,
              "is_start_position_verified" => false,
              "is_end_position_verified" => false,
              "start_date" => "2010-01-01T01:00:00Z",
              "end_date" => "2010-01-02T01:00:00Z",
              "ending_cross_street" => "Douglas Ave",
              "location_method" => "channel-device-method",
              "is_start_date_verified" => false,
              "is_end_date_verified" => false,
              "vehicle_impact" => "some-lanes-closed",
              "reduced_speed_limit_kph" => 88.514,
              "types_of_work" => [
                %{
                  "is_architectural_change" => true,
                  "type_name" => "surface-work"
                }
              ],
              "worker_presence" => %{
                "are_workers_present" => false
              },
              "work_zone_type" => "static",
              "lanes" => [
                %{
                  "order" => 1,
                  "restrictions" => [
                    %{
                      "type" => "reduced-width",
                      # Map of List of Maps of Map of List of Map of Lists of Map of Primitive
                      "UNIT" => "feet",
                      "value" => 10
                    }
                  ],
                  "status" => "open",
                  "type" => "general"
                },
                %{
                  "order" => 2,
                  "status" => "closed",
                  "type" => "general"
                }
              ]
            },
            "geometry" => %{
              "type" => "LineString",
              "Coordinates" => [
                [
                  -93.776684050999961,
                  41.617961698000045
                ],
                [
                  -93.776682957,
                  41.618244962000063
                ],
                [
                  -93.776677372999984,
                  41.619603362000078
                ],
                [
                  -93.776674365999952,
                  41.620322783000063
                ],
                [
                  -93.776671741999962,
                  41.620950321000066
                ],
                [
                  -93.776688974999956,
                  41.622297226000057
                ]
              ]
            }
          }
        ]
      }
    ]
  end
end
