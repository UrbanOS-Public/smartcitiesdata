defmodule DiscoveryApiWeb.DatasetQueryControllerTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo

  describe "fetching csv data" do
    setup do
      allow(DiscoveryApi.Data.Retriever.get_dataset("test"), return: %{:system_name => "coda__test_dataset"})

      allow(Prestige.execute(any()),
        return: []
      )

      allow(Prestige.execute(any(), catalog: "hive", schema: "default"),
        return: [[1, 2, 3], [4, 5, 6]]
      )

      allow(Prestige.prefetch(any()),
        return: [["id", "bigint", "", ""], ["one", "bigint", "", ""], ["two", "bigint", "", ""]]
      )

      :ok
    end

    test "returns csv", %{conn: conn} do
      actual = conn |> put_req_header("accept", "text/csv") |> get("/api/v1/dataset/test/query") |> response(200)
      assert "id,one,two\n1,2,3\n4,5,6\n" == actual
    end

    test "selects from the table specified in the dataset definition", %{conn: conn} do
      conn |> put_req_header("accept", "text/csv") |> get("/api/v1/dataset/test/query") |> response(200)

      assert_called Prestige.execute("describe hive.default.coda__test_dataset"), once()
      assert_called Prestige.execute("SELECT * FROM coda__test_dataset", catalog: "hive", schema: "default"), once()
    end

    test "selects using the where clause provided", %{conn: conn} do
      conn |> put_req_header("accept", "text/csv") |> get("/api/v1/dataset/test/query", where: "one=1") |> response(200)

      assert_called Prestige.execute("SELECT * FROM coda__test_dataset WHERE one=1", catalog: "hive", schema: "default"),
                    once()
    end

    test "selects using the order by clause provided", %{conn: conn} do
      conn |> put_req_header("accept", "text/csv") |> get("/api/v1/dataset/test/query", orderBy: "one") |> response(200)

      assert_called Prestige.execute("SELECT * FROM coda__test_dataset ORDER BY one", catalog: "hive", schema: "default"),
                    once()
    end

    test "selects using the limit clause provided", %{conn: conn} do
      conn |> put_req_header("accept", "text/csv") |> get("/api/v1/dataset/test/query", limit: "200") |> response(200)

      assert_called Prestige.execute("SELECT * FROM coda__test_dataset LIMIT 200", catalog: "hive", schema: "default"),
                    once()
    end

    test "selects using the group by clause provided", %{conn: conn} do
      conn |> put_req_header("accept", "text/csv") |> get("/api/v1/dataset/test/query", groupBy: "one") |> response(200)

      assert_called Prestige.execute("SELECT * FROM coda__test_dataset GROUP BY one", catalog: "hive", schema: "default"),
                    once()
    end

    test "selects using multiple clauses provided", %{conn: conn} do
      conn
      |> put_req_header("accept", "text/csv")
      |> get("/api/v1/dataset/test/query", where: "one=1", orderBy: "one", limit: "200", groupBy: "one")
      |> response(200)

      assert_called Prestige.execute("SELECT * FROM coda__test_dataset WHERE one=1 ORDER BY one LIMIT 200 GROUP BY one",
                      catalog: "hive",
                      schema: "default"
                    ),
                    once()
    end

    test "selects using columns provided", %{conn: conn} do
      conn
      |> put_req_header("accept", "text/csv")
      |> get("/api/v1/dataset/test/query", columns: "id,one,two")
      |> response(200)

      assert_called Prestige.execute("SELECT id, one, two FROM coda__test_dataset", catalog: "hive", schema: "default"),
                    once()
    end
  end

  describe "fetching json" do
    setup do
      allow(DiscoveryApi.Data.Retriever.get_dataset("test"), return: %{:system_name => "coda__test_dataset"})

      allow(
        Prestige.execute("SELECT * FROM coda__test_dataset",
          catalog: "hive",
          schema: "default",
          rows_as_maps: true
        ),
        return: [%{id: 1, name: "Joe", age: 21}, %{id: 2, name: "Robby", age: 32}]
      )

      :ok
    end

    test "returns json", %{conn: conn} do
      actual =
        conn
        |> put_req_header("accept", "application/json")
        |> get("/api/v1/dataset/test/query")
        |> response(200)

      assert Jason.decode!(actual) == [
               %{"id" => 1, "name" => "Joe", "age" => 21},
               %{"id" => 2, "name" => "Robby", "age" => 32}
             ]

      assert_called Prestige.execute("SELECT * FROM coda__test_dataset",
                      catalog: "hive",
                      schema: "default",
                      rows_as_maps: true
                    ),
                    once()
    end
  end

  describe "error cases" do
    test "dataset does not exist returns Not Found", %{conn: conn} do
      allow(DiscoveryApi.Data.Retriever.get_dataset("bobber"), return: nil)
      allow(Prestige.execute(any()), return: [])

      conn
      |> put_req_header("accept", "text/csv")
      |> get("/api/v1/dataset/bobber/query", columns: "id,one,two")
      |> response(404)

      assert_called Prestige.execute(any(), catalog: "hive", schema: "default"),
                    times(0)
    end

    test "table does not exist returns Not Found", %{conn: conn} do
      allow(DiscoveryApi.Data.Retriever.get_dataset("no_exist"), return: %{:system_name => "coda__no_exist"})
      allow(Prestige.execute(any()), return: [])
      allow(Prestige.execute(any(), catalog: "hive", schema: "default"), return: [])
      allow(Prestige.prefetch(any()), return: [])

      conn
      |> put_req_header("accept", "text/csv")
      |> get("/api/v1/dataset/no_exist/query", columns: "id,one,two")
      |> response(404)

      assert_called Prestige.execute(any(), catalog: "hive", schema: "default"),
                    times(0)
    end
  end

  describe "malice cases" do
    setup do
      allow(DiscoveryApi.Data.Retriever.get_dataset("bobber"), return: %{:system_name => "coda__test_dataset"})
      allow(Prestige.execute(any(), catalog: "hive", schema: "default"), return: [])
      allow(Prestige.execute(any()), return: [])

      allow(Prestige.prefetch(any()),
        return: [["id", "bigint", "", ""], ["one", "bigint", "", ""], ["two", "bigint", "", ""]]
      )

      :ok
    end

    test "queries cannot contain semicolons", %{conn: conn} do
      conn
      |> put_req_header("accept", "text/csv")
      |> get("/api/v1/dataset/bobber/query", columns: "id,one; select * from system; two")
      |> response(400)

      assert_called Prestige.execute(any(), catalog: "hive", schema: "default"),
                    times(0)
    end

    test "queries cannot contain block comments", %{conn: conn} do
      conn
      |> put_req_header("accept", "text/csv")
      |> get("/api/v1/dataset/bobber/query", orderBy: "/* This is a comment */")
      |> response(400)

      assert_called Prestige.execute(any(), catalog: "hive", schema: "default"),
                    times(0)
    end

    test "queries cannot contain single-line comments", %{conn: conn} do
      conn
      |> put_req_header("accept", "text/csv")
      |> get("/api/v1/dataset/bobber/query", orderBy: "-- This is a comment")
      |> response(400)

      assert_called Prestige.execute(any(), catalog: "hive", schema: "default"),
                    times(0)
    end
  end
end
