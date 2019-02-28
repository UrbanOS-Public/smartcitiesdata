defmodule DiscoveryApiWeb.DatasetQueryControllerTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo

  describe "fetching data from Presto" do
    setup do
      allow Prestige.execute("describe hive.default.test"),
        return: []

      allow Prestige.execute("select * from test", catalog: "hive", schema: "default"),
        return: [[1, 2, 3], [4, 5, 6]]

      allow Prestige.prefetch(any()),
        return: [["id", "bigint", "", ""], ["one", "bigint", "", ""], ["two", "bigint", "", ""]]

      :ok
    end

    test "returns data in CSV format", %{conn: conn} do
      conn = conn |> put_req_header("accept", "text/csv")
      actual = get(conn, "/v1/api/dataset/test/csv") |> response(200)
      assert "id,one,two\n1,2,3\n4,5,6\n" == actual
    end

    test "handles unknown media type", %{conn: conn} do
      conn = conn |> put_req_header("accept", "application/json")
      get(conn, "/v1/api/dataset/test/csv") |> response(415)
    end
  end
end
