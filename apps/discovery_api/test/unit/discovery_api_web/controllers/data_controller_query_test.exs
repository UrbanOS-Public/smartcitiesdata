defmodule DiscoveryApiWeb.DataController.QueryTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo
  import Checkov
  import SmartCity.TestHelper
  alias DiscoveryApi.Data.{Model, SystemNameCache}
  alias DiscoveryApiWeb.Utilities.ModelAccessUtils
  alias DiscoveryApi.Services.PrestoService

  @dataset_id "test"
  @system_name "coda__test_dataset"
  @org_name "org1"
  @data_name "data1"
  @feature_type "FeatureCollection"

  setup do
    allow(PrestoService.is_select_statement?(any()), return: true)
    allow(PrestoService.get_affected_tables(any(), any()), return: {:ok, []})
    allow(ModelAccessUtils.has_access?(any(), any()), return: true, meck_options: [:passthrough])

    model =
      Helper.sample_model(%{
        id: @dataset_id,
        systemName: @system_name,
        name: @data_name,
        private: false,
        lastUpdatedDate: nil,
        queries: 7,
        downloads: 9,
        schema: [
          %{name: "id", type: "integer"},
          %{name: "name", type: "string"}
        ]
      })

    allow(SystemNameCache.get(@org_name, @data_name), return: @dataset_id)
    allow(Model.get(@dataset_id), return: model)

    allow(Prestige.new_session(any()), return: :connection)

    allow(Prestige.query!(:connection, "describe #{@system_name}"),
      return: %Prestige.Result{
        columns: :doesnt_matter,
        presto_headers: :doesnt_matter,
        rows: [["id", "bigint", "", ""], ["name", "varchar", "", ""]]
      }
    )

    allow(Prestige.stream!(:connection, contains_string(@system_name)), return: [:to_map])

    allow(Prestige.Result.as_maps(:to_map),
      return: [%{"id" => 1, "name" => "Joe"}, %{"id" => 2, "name" => "Robby"}]
    )

    allow(Redix.command!(any(), any()), return: :does_not_matter)

    :ok
  end

  describe "query parameters" do
    data_test "selects from the table specified in the dataset definition", %{conn: conn} do
      conn |> put_req_header("accept", "text/csv") |> get(url) |> response(200)

      assert_called(Prestige.query!(:connection, "describe #{@system_name}"), once())
      assert_called(Prestige.stream!(:connection, "SELECT id, name FROM #{@system_name}"), once())

      where(
        url: [
          "/api/v1/dataset/test/query",
          "/api/v1/organization/org1/dataset/data1/query"
        ]
      )
    end

    data_test "selects using the where clause provided", %{conn: conn} do
      conn |> put_req_header("accept", "text/csv") |> get(url, where: "name='Robby'") |> response(200)

      assert_called(Prestige.stream!(:connection, "SELECT id, name FROM #{@system_name} WHERE name='Robby'"), once())

      where(
        url: [
          "/api/v1/dataset/test/query",
          "/api/v1/organization/org1/dataset/data1/query"
        ]
      )
    end

    data_test "selects using the order by clause provided", %{conn: conn} do
      conn |> put_req_header("accept", "text/csv") |> get(url, orderBy: "id") |> response(200)

      assert_called(Prestige.stream!(:connection, "SELECT id, name FROM #{@system_name} ORDER BY id"), once())

      where(
        url: [
          "/api/v1/dataset/test/query",
          "/api/v1/organization/org1/dataset/data1/query"
        ]
      )
    end

    data_test "selects using the limit clause provided", %{conn: conn} do
      conn |> put_req_header("accept", "text/csv") |> get(url, limit: "200") |> response(200)

      assert_called(Prestige.stream!(:connection, "SELECT id, name FROM #{@system_name} LIMIT 200"), once())

      where(
        url: [
          "/api/v1/dataset/test/query",
          "/api/v1/organization/org1/dataset/data1/query"
        ]
      )
    end

    data_test "selects using the group by clause provided", %{conn: conn} do
      conn |> put_req_header("accept", "text/csv") |> get(url, groupBy: "one") |> response(200)

      assert_called(Prestige.stream!(:connection, "SELECT id, name FROM #{@system_name} GROUP BY one"), once())

      where(
        url: [
          "/api/v1/dataset/test/query",
          "/api/v1/organization/org1/dataset/data1/query"
        ]
      )
    end

    data_test "selects using multiple clauses provided", %{conn: conn} do
      conn
      |> put_req_header("accept", "text/csv")
      |> get(url, where: "id=1", orderBy: "name", limit: "200", groupBy: "name")
      |> response(200)

      assert_called(
        Prestige.stream!(:connection, "SELECT id, name FROM #{@system_name} WHERE id=1 GROUP BY name ORDER BY name LIMIT 200"),
        once()
      )

      where(
        url: [
          "/api/v1/dataset/test/query",
          "/api/v1/organization/org1/dataset/data1/query"
        ]
      )
    end

    data_test "selects using columns provided returns only those columns of data", %{conn: conn} do
      conn
      |> put_req_header("accept", "text/csv")
      |> get(url, columns: "id")
      |> response(200)

      assert_called(Prestige.stream!(:connection, "SELECT id FROM #{@system_name}"), once())

      where(
        url: [
          "/api/v1/dataset/test/query",
          "/api/v1/organization/org1/dataset/data1/query"
        ]
      )
    end

    data_test "increments dataset queries count when dataset query is requested", %{conn: conn} do
      conn
      |> put_req_header("accept", "text/csv")
      |> get(url, columns: "id, name")
      |> response(200)

      eventually(fn -> assert_called(Redix.command!(:redix, ["INCR", "smart_registry:queries:count:test"])) end)

      where(
        url: [
          "/api/v1/dataset/test/query",
          "/api/v1/organization/org1/dataset/data1/query",
          "/api/v1/dataset/test/query?_format=json",
          "/api/v1/organization/org1/dataset/data1/query?_format=json"
        ]
      )
    end
  end

  describe "error cases" do
    test "table does not exist returns Not Found", %{conn: conn} do
      allow(Model.get("no_exist"),
        return: %Model{:id => "test", :systemName => "coda__no_exist", private: false}
      )

      allow(Prestige.query!(:connection, any()), return: %Prestige.Result{columns: :doesnt_matter, presto_headers: :doesnt_matter, rows: []})

      query_string = "SELECT id, one, two FROM coda__no_exist"

      conn
      |> put_req_header("accept", "text/csv")
      |> get("/api/v1/dataset/no_exist/query", columns: "id,one,two")
      |> response(404)

      assert_called(Prestige.stream!(:connection, query_string), times(0))
    end
  end

  describe "malice cases" do
    test "json queries cannot contain semicolons", %{conn: conn} do
      conn
      |> put_req_header("accept", "application/json")
      |> get("/api/v1/organization/org1/dataset/data1/query", columns: "id,one; select id, name from system; two")
      |> response(400)

      assert_called(
        Prestige.stream!(:connection, "SELECT id, one; select id, name from system; two FROM coda__test_dataset"),
        times(0)
      )
    end

    test "csv queries cannot contain semicolons", %{conn: conn} do
      conn
      |> put_req_header("accept", "text/csv")
      |> get("/api/v1/organization/org1/dataset/data1/query", columns: "id,one; select id, name from system; two")
      |> response(400)

      assert_called(
        Prestige.stream!(:connection, "SELECT id, one; select id, name from system; two FROM coda__test_dataset"),
        times(0)
      )
    end

    test "queries cannot contain block comments", %{conn: conn} do
      query_string = "SELECT id, name FROM coda__test_dataset ORDER BY /* This is a comment */"

      conn
      |> put_req_header("accept", "text/csv")
      |> get("/api/v1/organization/org1/dataset/data1/query", orderBy: "/* This is a comment */")
      |> response(400)

      assert_called(Prestige.stream!(:connection, query_string), times(0))
    end

    test "queries cannot contain single-line comments", %{conn: conn} do
      query_string = "SELECT id, name FROM coda__test_dataset ORDER BY -- This is a comment"

      conn
      |> put_req_header("accept", "text/csv")
      |> get("/api/v1/organization/org1/dataset/data1/query", orderBy: "-- This is a comment")
      |> response(400)

      assert_called(Prestige.stream!(:connection, query_string), times(0))
    end
  end

  describe "query geojson" do
    setup do
      model =
        Helper.sample_model(%{
          id: "geojson",
          systemName: "geojson__geojson",
          name: "geojson",
          private: false,
          lastUpdatedDate: nil,
          queries: 7,
          downloads: 9,
          sourceFormat: "geojson"
        })

      allow(SystemNameCache.get("geojson", "geojson"), return: "geojson__geojson")
      allow(Model.get(any()), return: model)
      allow(Model.get_all(), return: [model])

      allow(Prestige.stream!(:connection, "SELECT id, name FROM geojson"),
        return: [:any]
      )

      allow(Redix.command!(any(), any()), return: :doesnt_matter)

      allow(PrestoService.get_column_names(any(), any(), any()), return: {:ok, ["feature"]})
      allow(PrestoService.build_query(any(), any(), any(), any()), return: {:ok, "SELECT id, name FROM geojson"})
      allow(PrestoService.is_select_statement?(any()), return: true)
      allow(PrestoService.get_affected_tables(any(), any()), return: {:ok, ["geojson__geojson"]})
      allow(ModelAccessUtils.has_access?(any(), any()), return: true)

      :ok
    end

    data_test "returns geojson", %{conn: conn} do
      allow(Prestige.Result.as_maps(any()),
        return: [
          %{"feature" => "{\"geometry\": {\"coordinates\": [1, 0]}}"},
          %{"feature" => "{\"geometry\": {\"coordinates\": [[0, 1]]}}"}
        ]
      )

      actual =
        conn
        |> put_req_header("accept", "application/geo+json")
        |> get(url)
        |> response(200)

      assert Jason.decode!(actual) == %{
               "features" => [
                 %{
                   "geometry" => %{
                     "coordinates" => [1, 0]
                   }
                 },
                 %{
                   "geometry" => %{
                     "coordinates" => [[0, 1]]
                   }
                 }
               ],
               "bbox" => [0, 0, 1, 1],
               "name" => "geojson__geojson",
               "type" => @feature_type
             }

      assert_called(Prestige.stream!(:connection, "SELECT id, name FROM geojson"), once())

      where(
        url: [
          "/api/v1/dataset/geojson/query",
          "/api/v1/organization/geojson/dataset/geojson/query"
        ]
      )
    end
  end

  describe "metrics" do
    data_test "increments dataset download count when user hits api", %{conn: conn} do
      conn
      |> get(url)
      |> response(200)

      eventually(fn -> assert_called(Redix.command!(:redix, ["INCR", "smart_registry:queries:count:#{@dataset_id}"])) end)

      where(
        url: [
          "/api/v1/dataset/test/query",
          "/api/v1/organization/org1/dataset/data1/query"
        ]
      )
    end
  end

  describe "query dataset with json type fields" do
    setup do
      allow(PrestoService.is_select_statement?(any()), return: true)
      allow(PrestoService.get_affected_tables(any(), any()), return: {:ok, []})
      allow(ModelAccessUtils.has_access?(any(), any()), return: true, meck_options: [:passthrough])

      model =
        Helper.sample_model(%{
          id: "123456",
          systemName: "nest_test",
          name: "nest",
          private: false,
          lastUpdatedDate: nil,
          queries: 7,
          downloads: 9,
          schema: [
            %{name: "id", type: "integer"},
            %{name: "json_field", type: "json"}
          ]
        })

      allow(SystemNameCache.get(@org_name, "nest"), return: "123456")

      allow(Model.get("123456"), return: model)

      allow(Prestige.query!(:connection, "describe nest_test"),
        return: :to_nest_prefetch
      )

      allow(Prestige.stream!(:connection, contains_string("nest_test")), return: [:result])

      allow(Prestige.Result.as_maps(:result),
        return: [
          %{"json_field" => Jason.encode!(%{"id" => 4, "name" => "Paul"})},
          %{"json_field" => Jason.encode!(%{"id" => 5, "name" => ["John", "Peter", %{"name" => "Henry"}]})}
        ]
      )

      allow(PrestoService.get_column_names(any(), any(), any()), return: {:ok, ["json_field"]}, meck_options: [:passthrough])

      :ok
    end

    data_test "returns json 'string' fields as valid json", %{conn: conn} do
      body = conn |> put_req_header("accept", "application/json") |> get(url) |> response(200)

      expected_body = [
        %{"json_field" => %{"id" => 4, "name" => "Paul"}},
        %{"json_field" => %{"id" => 5, "name" => ["John", "Peter", %{"name" => "Henry"}]}}
      ]

      assert(Jason.decode!(body) == expected_body)

      where(
        url: [
          "/api/v1/dataset/123456/query",
          "/api/v1/organization/org1/dataset/nest/query"
        ]
      )
    end
  end
end
