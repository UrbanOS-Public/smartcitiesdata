defmodule DiscoveryApiWeb.DatasetDownloadControllerTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo

  describe "fetching csv data" do
    setup do
      allow(Prestige.execute("describe hive.default.test"),
        return: []
      )

      allow(Prestige.execute("select * from test", catalog: "hive", schema: "default"),
        return: [[1, 2, 3], [4, 5, 6]]
      )

      allow(Prestige.prefetch(any()),
        return: [["id", "bigint", "", ""], ["one", "bigint", "", ""], ["two", "bigint", "", ""]]
      )

      :ok
    end

    test "returns data in CSV format, given an accept header for it", %{conn: conn} do
      conn = conn |> put_req_header("accept", "text/csv")
      actual = conn |> get("/api/v1/dataset/test/download") |> response(200)
      assert "id,one,two\n1,2,3\n4,5,6\n" == actual
    end

    test "returns data in CSV format, given a query parameter for it", %{conn: conn} do
      actual = conn |> get("/api/v1/dataset/test/download?_format=csv") |> response(200)
      assert "id,one,two\n1,2,3\n4,5,6\n" == actual
    end

    test "returns data in CSV format, given no accept header", %{conn: conn} do
      actual = conn |> get("/api/v1/dataset/test/download") |> response(200)
      assert "id,one,two\n1,2,3\n4,5,6\n" == actual
    end
  end

  describe "fetching json data" do
    setup do
      allow(
        Prestige.execute("select * from test",
          catalog: "hive",
          schema: "default",
          rows_as_maps: true
        ),
        return: [%{id: 1, name: "Joe", age: 21}, %{id: 2, name: "Robby", age: 32}]
      )

      :ok
    end

    test "returns data in JSON format, given an accept header for it", %{conn: conn} do
      conn = put_req_header(conn, "accept", "application/json")
      actual = conn |> get("/api/v1/dataset/test/download") |> response(200)

      assert Jason.decode!(actual) == [
               %{"id" => 1, "name" => "Joe", "age" => 21},
               %{"id" => 2, "name" => "Robby", "age" => 32}
             ]
    end

    test "returns data in JSON format, given a query parameter for it", %{conn: conn} do
      actual = conn |> get("/api/v1/dataset/test/download?_format=json") |> response(200)

      assert Jason.decode!(actual) == [
               %{"id" => 1, "name" => "Joe", "age" => 21},
               %{"id" => 2, "name" => "Robby", "age" => 32}
             ]
    end
  end
end
