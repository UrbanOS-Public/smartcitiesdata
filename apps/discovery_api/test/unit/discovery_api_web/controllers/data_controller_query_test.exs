defmodule DiscoveryApiWeb.DataController.QueryTest do
  use DiscoveryApiWeb.ConnCase
  import Mox
  import Checkov
  alias DiscoveryApi.Data.{Model, SystemNameCache}

  setup :verify_on_exit!
  setup :set_mox_from_context

  @dataset_id "test"
  @system_name "coda__test_dataset"
  @org_name "org1"
  @data_name "data1"
  @feature_type "FeatureCollection"

  setup do
    stub(PrestoServiceMock, :is_select_statement?, fn _query -> true end)
    stub(PrestoServiceMock, :get_affected_tables, fn _arg1, _arg2 -> {:ok, []} end)
    stub(PrestoServiceMock, :get_column_names, fn _session, _dataset_name, _columns -> {:ok, ["id", "name"]} end)
    stub(PrestoServiceMock, :build_query, fn _params, _dataset_name, _columns, _schema -> {:ok, "SELECT id, name FROM #{@system_name}"} end)
    stub(ModelAccessUtilsMock, :has_access?, fn _arg1, _arg2 -> true end)

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

    # Use :meck for modules without dependency injection
    :meck.expect(SystemNameCache, :get, fn @org_name, @data_name -> @dataset_id end)
    :meck.expect(Model, :get, fn @dataset_id -> model end)
    
    # ModelMock is used by QueryAccessUtils through dependency injection
    stub(ModelMock, :get, fn @dataset_id -> model end)
    stub(ModelMock, :get_all, fn -> [model] end)

    stub(PrestigeMock, :new_session, fn _opts -> :connection end)

    on_exit(fn -> 
      try do
        :meck.unload(SystemNameCache)
      rescue
        _ -> :ok
      end
      try do
        :meck.unload(Model)
      rescue
        _ -> :ok
      end
    end)

    stub(PrestigeMock, :query!, fn :connection, "describe #{@system_name}" ->
      %{
        __struct__: Prestige.Result,
        columns: :doesnt_matter,
        presto_headers: :doesnt_matter,
        rows: [["id", "bigint", "", ""], ["name", "varchar", "", ""]]
      }
    end)

    stub(PrestigeMock, :stream!, fn :connection, _query -> [:to_map] end)

    stub(PrestigeResultMock, :as_maps, fn :to_map ->
      [%{"id" => 1, "name" => "Joe"}, %{"id" => 2, "name" => "Robby"}]
    end)

    stub(RedixMock, :command!, fn _arg1, _arg2 -> :does_not_matter end)

    :ok
  end

  describe "query parameters" do
    data_test "selects from the table specified in the dataset definition", %{conn: conn} do
      conn |> put_req_header("accept", "text/csv") |> get(url) |> response(200)

      where(
        url: [
          "/api/v1/dataset/test/query",
          "/api/v1/organization/org1/dataset/data1/query"
        ]
      )
    end

    data_test "selects using the where clause provided", %{conn: conn} do
      conn |> put_req_header("accept", "text/csv") |> get(url, where: "name='Robby'") |> response(200)

      where(
        url: [
          "/api/v1/dataset/test/query",
          "/api/v1/organization/org1/dataset/data1/query"
        ]
      )
    end

    data_test "selects using the order by clause provided", %{conn: conn} do
      conn |> put_req_header("accept", "text/csv") |> get(url, orderBy: "id") |> response(200)

      where(
        url: [
          "/api/v1/dataset/test/query",
          "/api/v1/organization/org1/dataset/data1/query"
        ]
      )
    end

    data_test "selects using the limit clause provided", %{conn: conn} do
      conn |> put_req_header("accept", "text/csv") |> get(url, limit: "200") |> response(200)

      where(
        url: [
          "/api/v1/dataset/test/query",
          "/api/v1/organization/org1/dataset/data1/query"
        ]
      )
    end

    data_test "selects using the group by clause provided", %{conn: conn} do
      conn |> put_req_header("accept", "text/csv") |> get(url, groupBy: "one") |> response(200)

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
      :meck.expect(Model, :get, fn "no_exist" ->
        %Model{:id => "test", :systemName => "coda__no_exist", private: false}
      end)

      stub(PrestigeMock, :query!, fn :connection, _query -> 
        %Prestige.Result{columns: :doesnt_matter, presto_headers: :doesnt_matter, rows: []}
      end)

      conn
      |> put_req_header("accept", "text/csv")
      |> get("/api/v1/dataset/no_exist/query", columns: "id,one,two")
      |> response(404)
    end
  end

  describe "malice cases" do
    test "json queries cannot contain semicolons", %{conn: conn} do
      conn
      |> put_req_header("accept", "application/json")
      |> get("/api/v1/organization/org1/dataset/data1/query", columns: "id,one; select id, name from system; two")
      |> response(400)
    end

    test "csv queries cannot contain semicolons", %{conn: conn} do
      conn
      |> put_req_header("accept", "text/csv")
      |> get("/api/v1/organization/org1/dataset/data1/query", columns: "id,one; select id, name from system; two")
      |> response(400)
    end

    test "queries cannot contain block comments", %{conn: conn} do
      conn
      |> put_req_header("accept", "text/csv")
      |> get("/api/v1/organization/org1/dataset/data1/query", orderBy: "/* This is a comment */")
      |> response(400)
    end

    test "queries cannot contain single-line comments", %{conn: conn} do
      conn
      |> put_req_header("accept", "text/csv")
      |> get("/api/v1/organization/org1/dataset/data1/query", orderBy: "-- This is a comment")
      |> response(400)
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

      # Use :meck for modules without dependency injection
      :meck.expect(SystemNameCache, :get, fn "geojson", "geojson" -> "geojson__geojson" end)
      :meck.expect(Model, :get, fn _id -> model end)
      :meck.expect(Model, :get_all, fn -> [model] end)

      stub(PrestigeMock, :stream!, fn :connection, "SELECT id, name FROM geojson" ->
        [:any]
      end)

      on_exit(fn -> 
        try do
          :meck.unload(SystemNameCache)
        rescue
          _ -> :ok
        end
        try do
          :meck.unload(Model)
        rescue
          _ -> :ok
        end
      end)

      stub(RedixMock, :command!, fn _arg1, _arg2 -> :doesnt_matter end)

      stub(PrestoServiceMock, :get_column_names, fn _arg1, _arg2, _arg3 -> {:ok, ["feature"]} end)
      stub(PrestoServiceMock, :build_query, fn _arg1, _arg2, _arg3, _arg4 -> {:ok, "SELECT id, name FROM geojson"} end)
      stub(PrestoServiceMock, :is_select_statement?, fn _query -> true end)
      stub(PrestoServiceMock, :get_affected_tables, fn _arg1, _arg2 -> {:ok, ["geojson__geojson"]} end)
      stub(ModelAccessUtilsMock, :has_access?, fn _arg1, _arg2 -> true end)

      :ok
    end

    data_test "returns geojson", %{conn: conn} do
      stub(PrestigeResultMock, :as_maps, fn [:any] ->
        [
          %{"feature" => "{\"geometry\": {\"coordinates\": [1, 0]}}"},
          %{"feature" => "{\"geometry\": {\"coordinates\": [[0, 1]]}}"}
        ]
      end)

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
      stub(PrestoServiceMock, :is_select_statement?, fn _query -> true end)
      stub(PrestoServiceMock, :get_affected_tables, fn _arg1, _arg2 -> {:ok, []} end)
      stub(PrestoServiceMock, :get_column_names, fn _session, _dataset_name, _columns -> {:ok, ["json_field"]} end)
      stub(PrestoServiceMock, :build_query, fn _params, _dataset_name, _columns, _schema -> {:ok, "SELECT json_field FROM nest_test"} end)
      stub(ModelAccessUtilsMock, :has_access?, fn _arg1, _arg2 -> true end)

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

      # Use :meck for modules without dependency injection
      :meck.expect(SystemNameCache, :get, fn @org_name, "nest" -> "123456" end)
      :meck.expect(Model, :get, fn "123456" -> model end)

      stub(PrestigeMock, :query!, fn :connection, "describe nest_test" ->
        :to_nest_prefetch
      end)

      on_exit(fn -> 
        try do
          :meck.unload(SystemNameCache)
        rescue
          _ -> :ok
        end
        try do
          :meck.unload(Model)
        rescue
          _ -> :ok
        end
      end)

      stub(PrestigeMock, :stream!, fn :connection, _query -> [:result] end)

      stub(PrestigeResultMock, :as_maps, fn :result ->
        [
          %{"json_field" => Jason.encode!(%{"id" => 4, "name" => "Paul"})},
          %{"json_field" => Jason.encode!(%{"id" => 5, "name" => ["John", "Peter", %{"name" => "Henry"}]})}
        ]
      end)

      stub(PrestoServiceMock, :get_column_names, fn _arg1, _arg2, _arg3 -> {:ok, ["json_field"]} end)

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
